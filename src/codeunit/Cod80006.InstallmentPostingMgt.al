codeunit 80006 "Installment Posting Mgt."
{
    permissions = TableData "Installment Payment Terms" = R ,
                  TableData "Cust. Ledger Entry" = RIMD,
                  TableData "Detailed Cust. Ledg. Entry" = RIMD;
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterFinalizePosting', '', false, false)]
    local procedure OnAfterFinalizeSalesPosting(
        var SalesHeader: Record "Sales Header";
        var SalesShipmentHeader: Record "Sales Shipment Header";
        var SalesInvoiceHeader: Record "Sales Invoice Header";
        var SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        var ReturnReceiptHeader: Record "Return Receipt Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        PreviewMode: Boolean;
        CommitIsSuppressed: Boolean)
    var
        InstallmentTerms: Record "Installment Payment Terms";
        CustLedgEntry: Record "Cust. Ledger Entry";
    begin
        if PreviewMode then exit;
        if SalesInvoiceHeader."No." = '' then exit;
        if SalesInvoiceHeader."Installment Code" = '' then exit;
        if not InstallmentTerms.Get(SalesInvoiceHeader."Installment Code") then exit;

        CustLedgEntry.SetRange("Document Type", CustLedgEntry."Document Type"::Invoice);
        CustLedgEntry.SetRange("Document No.", SalesInvoiceHeader."No.");
        CustLedgEntry.SetRange("Customer No.", SalesInvoiceHeader."Sell-to Customer No.");
        if CustLedgEntry.FindFirst() then
            SplitIntoInstallments(CustLedgEntry, InstallmentTerms);
    end;

    // ---------------------------------------------------------------
    // ROUTER: use percentage lines if defined, else equal split
    // ---------------------------------------------------------------
    local procedure SplitIntoInstallments(
        var OrigCLE: Record "Cust. Ledger Entry";
        InstallmentTerms: Record "Installment Payment Terms")
    var
        InstallmentLine: Record "Installment Terms Line";
    begin
        InstallmentLine.SetRange("Code", InstallmentTerms.Code);

        if InstallmentLine.Count() >= 2 then
            SplitByPercentage(OrigCLE, InstallmentTerms)
        else
            SplitEqually(OrigCLE, InstallmentTerms);
    end;

    // ---------------------------------------------------------------
    // MODE 1 — Custom percentage lines (50% / 25% / 25%)
    // ---------------------------------------------------------------
    local procedure SplitByPercentage(
        var OrigCLE: Record "Cust. Ledger Entry";
        InstallmentTerms: Record "Installment Payment Terms")
    var
        InstallmentLine: Record "Installment Terms Line";
        TotalAmount: Decimal;
        TotalAmountLCY: Decimal;
        LineAmount: Decimal;
        LineAmountLCY: Decimal;
        AccumulatedAmt: Decimal;
        AccumulatedAmtLCY: Decimal;
        DueDate: Date;
        BaseDate: Date;
        LineCount: Integer;
        CurrentLine: Integer;
    begin
        OrigCLE.CalcFields(Amount, "Amount (LCY)");
        TotalAmount := OrigCLE.Amount;
        TotalAmountLCY := OrigCLE."Amount (LCY)";
        BaseDate := OrigCLE."Posting Date";

        InstallmentLine.SetRange("Code", InstallmentTerms.Code);
        InstallmentLine.SetCurrentKey("Code", "Installment No.");
        LineCount := InstallmentLine.Count();
        CurrentLine := 0;

        if not InstallmentLine.FindSet() then exit;

        repeat
            CurrentLine += 1;
            DueDate := CalcDate(
                StrSubstNo('<%1D>', InstallmentLine."Days from Posting Date"), BaseDate);

            // Last line takes the remainder (handles rounding)
            if CurrentLine = LineCount then begin
                LineAmount := TotalAmount - AccumulatedAmt;
                LineAmountLCY := TotalAmountLCY - AccumulatedAmtLCY;
            end else begin
                LineAmount := Round(TotalAmount * InstallmentLine.Percentage / 100, 0.01);
                LineAmountLCY := Round(TotalAmountLCY * InstallmentLine.Percentage / 100, 0.01);
            end;

            AccumulatedAmt += LineAmount;
            AccumulatedAmtLCY += LineAmountLCY;

            if CurrentLine = 1 then begin
                UpdateDetailedEntry(OrigCLE."Entry No.", LineAmount, LineAmountLCY);
                OrigCLE."Due Date" := DueDate;
                OrigCLE.Description := CopyStr(
                    StrSubstNo('Installment 1/%1 - %2', LineCount, OrigCLE."Document No."), 1, 100);
                OrigCLE.Modify();
            end else
                CreateInstallmentEntry(OrigCLE, LineAmount, LineAmountLCY, DueDate, CurrentLine, LineCount);

        until InstallmentLine.Next() = 0;
    end;

    // ---------------------------------------------------------------
    // MODE 2 — Equal split fallback (original behaviour)
    // ---------------------------------------------------------------
    local procedure SplitEqually(
        var OrigCLE: Record "Cust. Ledger Entry";
        InstallmentTerms: Record "Installment Payment Terms")
    var
        TotalAmount: Decimal;
        TotalAmountLCY: Decimal;
        InstallmentAmt: Decimal;
        InstallmentAmtLCY: Decimal;
        Remainder: Decimal;
        RemainderLCY: Decimal;
        DueDate: Date;
        i: Integer;
        N: Integer;
    begin
        N := InstallmentTerms."No. of Installments";
        if N <= 1 then exit;

        OrigCLE.CalcFields(Amount, "Amount (LCY)");
        TotalAmount := OrigCLE.Amount;
        TotalAmountLCY := OrigCLE."Amount (LCY)";

        InstallmentAmt := Round(TotalAmount / N, 0.01);
        InstallmentAmtLCY := Round(TotalAmountLCY / N, 0.01);
        Remainder := TotalAmount - (InstallmentAmt * N);
        RemainderLCY := TotalAmountLCY - (InstallmentAmtLCY * N);

        DueDate := OrigCLE."Due Date";

        UpdateDetailedEntry(OrigCLE."Entry No.", InstallmentAmt, InstallmentAmtLCY);
        OrigCLE.Description := CopyStr(
            StrSubstNo('Installment 1/%1 - %2', N, OrigCLE."Document No."), 1, 100);
        OrigCLE."Due Date" := DueDate;
        OrigCLE.Modify();

        for i := 2 to N do begin
            DueDate := CalcDate(
                StrSubstNo('<%1D>', InstallmentTerms."Days Between Installments"), DueDate);
            if i = N then begin
                InstallmentAmt += Remainder;
                InstallmentAmtLCY += RemainderLCY;
            end;
            CreateInstallmentEntry(OrigCLE, InstallmentAmt, InstallmentAmtLCY, DueDate, i, N);
        end;
    end;

    // ---------------------------------------------------------------
    // Shared helpers (unchanged)
    // ---------------------------------------------------------------
    local procedure UpdateDetailedEntry(CLEEntryNo: Integer; NewAmount: Decimal; NewAmountLCY: Decimal)
    var
        DCLE: Record "Detailed Cust. Ledg. Entry";
    begin
        DCLE.SetRange("Cust. Ledger Entry No.", CLEEntryNo);
        DCLE.SetRange("Entry Type", DCLE."Entry Type"::"Initial Entry");
        if DCLE.FindFirst() then begin
            DCLE.Amount := NewAmount;
            DCLE."Amount (LCY)" := NewAmountLCY;
            DCLE."Debit Amount" := NewAmount;
            DCLE."Debit Amount (LCY)" := NewAmountLCY;
            DCLE."Credit Amount" := 0;
            DCLE."Credit Amount (LCY)" := 0;
            DCLE.Modify();
        end;
    end;

    local procedure CreateInstallmentEntry(
        OrigCLE: Record "Cust. Ledger Entry";
        Amount: Decimal;
        AmountLCY: Decimal;
        DueDate: Date;
        InstallmentNo: Integer;
        TotalInstallments: Integer)
    var
        NewCLE: Record "Cust. Ledger Entry";
        NewDCLE: Record "Detailed Cust. Ledg. Entry";
        NewCLENo: Integer;
        NewDCLENo: Integer;
    begin
        NewCLE.FindLast();
        NewCLENo := NewCLE."Entry No." + 1;
        NewDCLE.FindLast();
        NewDCLENo := NewDCLE."Entry No." + 1;

        NewCLE := OrigCLE;
        NewCLE."Entry No." := NewCLENo;
        NewCLE."Due Date" := DueDate;
        NewCLE."Document No." := CopyStr(
            OrigCLE."Document No." + '-I' + Format(InstallmentNo), 1, 20);
        NewCLE.Description := CopyStr(
            StrSubstNo('Installment %1/%2 - %3',
                InstallmentNo, TotalInstallments, OrigCLE."Document No."), 1, 100);
        NewCLE.Open := true;
        NewCLE."Closed at Date" := 0D;
        NewCLE."Closed by Entry No." := 0;
        NewCLE."Closed by Amount" := 0;
        NewCLE."Closed by Amount (LCY)" := 0;
        NewCLE.Insert();

        NewDCLE.Init();
        NewDCLE."Entry No." := NewDCLENo;
        NewDCLE."Cust. Ledger Entry No." := NewCLENo;
        NewDCLE."Entry Type" := NewDCLE."Entry Type"::"Initial Entry";
        NewDCLE."Posting Date" := OrigCLE."Posting Date";
        NewDCLE."Document Type" := OrigCLE."Document Type";
        NewDCLE."Document No." := NewCLE."Document No.";
        NewDCLE."Customer No." := OrigCLE."Customer No.";
        NewDCLE."Currency Code" := OrigCLE."Currency Code";
        NewDCLE.Amount := Amount;
        NewDCLE."Amount (LCY)" := AmountLCY;
        NewDCLE."Debit Amount" := Amount;
        NewDCLE."Debit Amount (LCY)" := AmountLCY;
        NewDCLE."Credit Amount" := 0;
        NewDCLE."Credit Amount (LCY)" := 0;
        NewDCLE."Initial Entry Due Date" := DueDate;
        NewDCLE."Initial Entry Global Dim. 1" := OrigCLE."Global Dimension 1 Code";
        NewDCLE."Initial Entry Global Dim. 2" := OrigCLE."Global Dimension 2 Code";
        NewDCLE."Ledger Entry Amount" := true;
        NewDCLE.Insert(true);
    end;
}