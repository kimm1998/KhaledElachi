codeunit 80008 "Installment Apply to Posted"
{
    // ---------------------------------------------------------------
    // PUBLIC: Apply installment split to an already-posted invoice
    // ---------------------------------------------------------------
    permissions = TableData "Installment Payment Terms" = R,
                  TableData "Cust. Ledger Entry" = RIMD,
                  TableData "Sales Invoice Header" = RIMD,
                  TableData "Detailed Cust. Ledg. Entry" = RIMD;
    procedure ApplyToPostedInvoice(InvoiceNo: Code[20]; CustomerNo: Code[20]; InstallmentCode: Code[20])
    var
        SalesInvHeader: Record "Sales Invoice Header";
        InstallmentTerms: Record "Installment Payment Terms";
        CustLedgEntry: Record "Cust. Ledger Entry";
        ExistingSubEntry: Record "Cust. Ledger Entry";
    begin
        // --- Guards ---
        if InstallmentCode = '' then
            Error('Installment Code must be specified.');

        if not InstallmentTerms.Get(InstallmentCode) then
            Error('Installment Code ''%1'' does not exist.', InstallmentCode);

        if not SalesInvHeader.Get(InvoiceNo) then
            Error('Posted Sales Invoice %1 was not found.', InvoiceNo);

        if SalesInvHeader."Installments Applied" then
            Error('Installments have already been applied to invoice %1.Reset them first before reapplying.', InvoiceNo);

        // Block if sub-entries already exist (e.g. split at posting time)
        ExistingSubEntry.SetRange("Customer No.", CustomerNo);
        ExistingSubEntry.SetFilter("Document No.", InvoiceNo + '-I*');
        ExistingSubEntry.SetRange("Document Type", ExistingSubEntry."Document Type"::Invoice);
        if not ExistingSubEntry.IsEmpty() then
            Error('Invoice %1 already has installment sub-entries. Reset them before reapplying.', InvoiceNo);

        // Find the open CLE
        CustLedgEntry.SetRange("Document Type", CustLedgEntry."Document Type"::Invoice);
        CustLedgEntry.SetRange("Document No.", InvoiceNo);
        CustLedgEntry.SetRange("Customer No.", CustomerNo);
        CustLedgEntry.SetRange(Open, true);
        if not CustLedgEntry.FindFirst() then
            Error('No open customer ledger entry found for invoice %1. The invoice may already be fully paid.', InvoiceNo);

        CustLedgEntry.CalcFields("Remaining Amount", "Remaining Amt. (LCY)");
        if CustLedgEntry."Remaining Amount" <= 0 then
            Error('The remaining amount on invoice %1 must be positive to apply installments.', InvoiceNo);

        // --- Split ---
        SplitIntoInstallments(CustLedgEntry, InstallmentTerms);

        // --- Mark invoice ---
        SalesInvHeader."Installments Applied" := true;
        SalesInvHeader."Installment Code Applied" := InstallmentCode;
        SalesInvHeader.Modify();

        // --- Audit log ---
        WriteLog(
            InvoiceNo, CustomerNo, InstallmentCode,
            CustLedgEntry."Remaining Amount",
            GetInstallmentCount(InstallmentTerms),
            SalesInvHeader."Currency Code",
            0); // 0 = Applied
    end;

    // ---------------------------------------------------------------
    // PUBLIC: Reset installments (only if no payments made yet)
    // ---------------------------------------------------------------
    procedure ResetInstallments(InvoiceNo: Code[20]; CustomerNo: Code[20])
    var
        SalesInvHeader: Record "Sales Invoice Header";
        SubCLE: Record "Cust. Ledger Entry";
        SubDCLE: Record "Detailed Cust. Ledg. Entry";
        OrigCLE: Record "Cust. Ledger Entry";
        OrigDCLE: Record "Detailed Cust. Ledg. Entry";
        TotalAmount: Decimal;
        TotalAmountLCY: Decimal;
        SavedInstallmentCode: Code[20];
        SavedCurrencyCode: Code[10];
        InstallmentCount: Integer;
    begin
        if not SalesInvHeader.Get(InvoiceNo) then
            Error('Posted Sales Invoice %1 was not found.', InvoiceNo);

        if not SalesInvHeader."Installments Applied" then
            Error('No installments have been applied to invoice %1.', InvoiceNo);

        SavedInstallmentCode := SalesInvHeader."Installment Code Applied";
        SavedCurrencyCode := SalesInvHeader."Currency Code";

        // --- Guard: block reset if any entry has been paid ---
        SubCLE.SetRange("Customer No.", CustomerNo);
        SubCLE.SetFilter("Document No.", InvoiceNo + '|' + InvoiceNo + '-I*');
        SubCLE.SetRange("Document Type", SubCLE."Document Type"::Invoice);
        if SubCLE.FindSet() then
            repeat
                // Check for any payment/application DCLEs
                SubDCLE.SetRange("Cust. Ledger Entry No.", SubCLE."Entry No.");
                SubDCLE.SetFilter("Entry Type", '<>%1', SubDCLE."Entry Type"::"Initial Entry");
                if not SubDCLE.IsEmpty() then
                    Error('Installment entry ''%1'' has payments applied to it. Reverse the payment before resetting installments.', SubCLE."Document No.");
            until SubCLE.Next() = 0;

        // --- Find original CLE ---
        OrigCLE.SetRange("Document Type", OrigCLE."Document Type"::Invoice);
        OrigCLE.SetRange("Document No.", InvoiceNo);
        OrigCLE.SetRange("Customer No.", CustomerNo);
        if not OrigCLE.FindFirst() then
            Error('Original customer ledger entry for invoice %1 was not found.', InvoiceNo);

        // --- Sum all DCLE Initial Entry amounts (original + sub-entries) ---
        OrigDCLE.SetRange("Cust. Ledger Entry No.", OrigCLE."Entry No.");
        OrigDCLE.SetRange("Entry Type", OrigDCLE."Entry Type"::"Initial Entry");
        if OrigDCLE.FindFirst() then begin
            TotalAmount := OrigDCLE.Amount;
            TotalAmountLCY := OrigDCLE."Amount (LCY)";
        end;

        SubCLE.SetRange("Customer No.", CustomerNo);
        SubCLE.SetFilter("Document No.", InvoiceNo + '-I*');
        SubCLE.SetRange("Document Type", SubCLE."Document Type"::Invoice);
        InstallmentCount := SubCLE.Count() + 1;

        if SubCLE.FindSet() then
            repeat
                SubDCLE.SetRange("Cust. Ledger Entry No.", SubCLE."Entry No.");
                SubDCLE.SetRange("Entry Type", SubDCLE."Entry Type"::"Initial Entry");
                if SubDCLE.FindFirst() then begin
                    TotalAmount += SubDCLE.Amount;
                    TotalAmountLCY += SubDCLE."Amount (LCY)";
                end;
            until SubCLE.Next() = 0;

        // --- Delete sub-entry DCLEs ---
        SubCLE.SetRange("Customer No.", CustomerNo);
        SubCLE.SetFilter("Document No.", InvoiceNo + '-I*');
        SubCLE.SetRange("Document Type", SubCLE."Document Type"::Invoice);
        if SubCLE.FindSet() then
            repeat
                SubDCLE.SetRange("Cust. Ledger Entry No.", SubCLE."Entry No.");
                SubDCLE.DeleteAll();
            until SubCLE.Next() = 0;

        // --- Delete sub-entry CLEs ---
        SubCLE.SetRange("Customer No.", CustomerNo);
        SubCLE.SetFilter("Document No.", InvoiceNo + '-I*');
        SubCLE.SetRange("Document Type", SubCLE."Document Type"::Invoice);
        SubCLE.DeleteAll();

        // --- Restore original CLE ---
        OrigCLE."Due Date" := SalesInvHeader."Due Date";
        OrigCLE.Description := CopyStr(StrSubstNo('Invoice %1', InvoiceNo), 1, 100);
        OrigCLE.Open := true;
        OrigCLE.Modify();

        // --- Restore original DCLE Initial Entry ---
        OrigDCLE.SetRange("Cust. Ledger Entry No.", OrigCLE."Entry No.");
        OrigDCLE.SetRange("Entry Type", OrigDCLE."Entry Type"::"Initial Entry");
        if OrigDCLE.FindFirst() then begin
            OrigDCLE.Amount := TotalAmount;
            OrigDCLE."Amount (LCY)" := TotalAmountLCY;
            OrigDCLE."Debit Amount" := TotalAmount;
            OrigDCLE."Debit Amount (LCY)" := TotalAmountLCY;
            OrigDCLE.Modify();
        end;

        // --- Clear flag ---
        SalesInvHeader."Installments Applied" := false;
        SalesInvHeader."Installment Code Applied" := '';
        SalesInvHeader.Modify();

        // --- Audit log ---
        WriteLog(InvoiceNo, CustomerNo, SavedInstallmentCode,
            TotalAmount, InstallmentCount, SavedCurrencyCode, 1); // 1 = Reset
    end;

    // ---------------------------------------------------------------
    // PRIVATE: Route to percentage or equal split
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

    local procedure SplitByPercentage(
        var OrigCLE: Record "Cust. Ledger Entry";
        InstallmentTerms: Record "Installment Payment Terms")
    var
        InstallmentLine: Record "Installment Terms Line";
        TotalAmount: Decimal;
        TotalAmountLCY: Decimal;
        LineAmount: Decimal;
        LineAmountLCY: Decimal;
        AccAmt: Decimal;
        AccAmtLCY: Decimal;
        DueDate: Date;
        LineCount: Integer;
        CurrentLine: Integer;
    begin
        TotalAmount := OrigCLE."Remaining Amount";
        TotalAmountLCY := OrigCLE."Remaining Amt. (LCY)";

        InstallmentLine.SetRange("Code", InstallmentTerms.Code);
        InstallmentLine.SetCurrentKey("Code", "Installment No.");
        LineCount := InstallmentLine.Count();
        CurrentLine := 0;

        if not InstallmentLine.FindSet() then exit;
        repeat
            CurrentLine += 1;
            DueDate := CalcDate(
                StrSubstNo('<%1D>', InstallmentLine."Days from Posting Date"),
                OrigCLE."Posting Date");

            if CurrentLine = LineCount then begin
                LineAmount := TotalAmount - AccAmt;
                LineAmountLCY := TotalAmountLCY - AccAmtLCY;
            end else begin
                LineAmount := Round(TotalAmount * InstallmentLine.Percentage / 100, 0.01);
                LineAmountLCY := Round(TotalAmountLCY * InstallmentLine.Percentage / 100, 0.01);
                AccAmt += LineAmount;
                AccAmtLCY += LineAmountLCY;
            end;

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

        TotalAmount := OrigCLE."Remaining Amount";
        TotalAmountLCY := OrigCLE."Remaining Amt. (LCY)";

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
        NewCLE."Document No." := CopyStr(OrigCLE."Document No." + '-I' + Format(InstallmentNo), 1, 20);
        NewCLE.Description := CopyStr(
            StrSubstNo('Installment %1/%2 - %3', InstallmentNo, TotalInstallments, OrigCLE."Document No."), 1, 100);
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

    local procedure GetInstallmentCount(InstallmentTerms: Record "Installment Payment Terms"): Integer
    var
        InstallmentLine: Record "Installment Terms Line";
    begin
        InstallmentLine.SetRange("Code", InstallmentTerms.Code);
        if InstallmentLine.Count() >= 2 then
            exit(InstallmentLine.Count());
        exit(InstallmentTerms."No. of Installments");
    end;

    local procedure WriteLog(DocNo: Code[20]; CustNo: Code[20]; InstCode: Code[20];
        RemAmt: Decimal; NoInstallments: Integer; CurrCode: Code[10]; ActionType: Option)
    var
        LogEntry: Record "Installment Application Log";
    begin
        LogEntry.Init();
        LogEntry."Document No." := DocNo;
        LogEntry."Customer No." := CustNo;
        LogEntry."Applied Date" := Today();
        LogEntry."Applied Time" := Time();
        LogEntry."Applied By" := CopyStr(UserId(), 1, 50);
        LogEntry."Installment Code" := InstCode;
        LogEntry."Remaining Amount" := RemAmt;
        LogEntry."No. of Installments" := NoInstallments;
        LogEntry."Currency Code" := CurrCode;
        LogEntry."Action Type" := ActionType;
        LogEntry.Insert(true);
    end;
}