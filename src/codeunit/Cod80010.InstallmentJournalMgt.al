codeunit 80010 "Installment Journal Mgt."
{
    Permissions = TableData "Installment Payment Terms" = R,
                  TableData "Installment Terms Line" = R,
                  TableData "Cust. Ledger Entry" = RM,
                  TableData "Sales Invoice Header" = RM,
                  TableData "Gen. Journal Line" = RIMD,
                  TableData "Gen. Journal Batch" = RIMD,
                  TableData "Gen. Journal Template" = R;

    procedure ApplyToPostedInvoice(InvoiceNo: Code[20]; CustomerNo: Code[20]; InstallmentCode: Code[20]; FromPosting: Boolean)
    var
        SalesInvHeader: Record "Sales Invoice Header";
        InstallmentTerms: Record "Installment Payment Terms";
        CustLedgEntry: Record "Cust. Ledger Entry";
        ExistingSubEntry: Record "Cust. Ledger Entry";
        RemainingAmount: Decimal;
        RemainingAmountLCY: Decimal;
        OriginalAmount: Decimal;
        OriginalAmountLCY: Decimal;
    begin
        if InstallmentCode = '' then
            Error('Installment Code must be specified.');

        if not InstallmentTerms.Get(InstallmentCode) then
            Error('Installment Code ''%1'' does not exist.', InstallmentCode);

        if not SalesInvHeader.Get(InvoiceNo) then
            Error('Posted Sales Invoice %1 was not found.', InvoiceNo);

        if SalesInvHeader."Installments Applied" then
            exit;

        ExistingSubEntry.SetRange("Customer No.", CustomerNo);
        ExistingSubEntry.SetFilter("Document No.", InvoiceNo + '-I*');
        ExistingSubEntry.SetRange("Document Type", ExistingSubEntry."Document Type"::Invoice);
        if not ExistingSubEntry.IsEmpty() then
            exit;

        CustLedgEntry.SetRange("Document Type", CustLedgEntry."Document Type"::Invoice);
        CustLedgEntry.SetRange("Document No.", InvoiceNo);
        CustLedgEntry.SetRange("Customer No.", CustomerNo);
        CustLedgEntry.SetRange(Open, true);
        if not CustLedgEntry.FindFirst() then begin
            if FromPosting then
                exit;
            Error('No open customer ledger entry found for invoice %1. The invoice may already be fully paid.', InvoiceNo);
        end;

        CustLedgEntry.CalcFields(Amount, "Amount (LCY)", "Remaining Amount", "Remaining Amt. (LCY)");
        OriginalAmount := CustLedgEntry.Amount;
        OriginalAmountLCY := CustLedgEntry."Amount (LCY)";
        RemainingAmount := CustLedgEntry."Remaining Amount";
        RemainingAmountLCY := CustLedgEntry."Remaining Amt. (LCY)";

        if RemainingAmount <= 0 then begin
            if FromPosting then
                exit;
            Error('The remaining amount on invoice %1 must be positive to apply installments.', InvoiceNo);
        end;

        EnsureInstallmentJournal();
        ClearInstallmentJournalLines();
        CreateJournalSplit(
            CustLedgEntry, SalesInvHeader, InstallmentTerms,
            OriginalAmount, OriginalAmountLCY,
            RemainingAmount, RemainingAmountLCY);
        PostInstallmentJournalLines();

        StampOriginalPostedAmounts(
            InvoiceNo, CustomerNo, OriginalAmount, OriginalAmountLCY);

        SalesInvHeader."Installments Applied" := true;
        SalesInvHeader."Installment Code Applied" := InstallmentCode;
        SalesInvHeader.Modify();

        WriteLog(
            InvoiceNo, CustomerNo, InstallmentCode,
            RemainingAmount,
            GetInstallmentCount(InstallmentTerms),
            SalesInvHeader."Currency Code",
            0);
    end;

    procedure ResetInstallments(InvoiceNo: Code[20]; CustomerNo: Code[20])
    var
        SalesInvHeader: Record "Sales Invoice Header";
        OrigCLE: Record "Cust. Ledger Entry";
        SubCLE: Record "Cust. Ledger Entry";
        SubDCLE: Record "Detailed Cust. Ledg. Entry";
        SavedInstallmentCode: Code[20];
        SavedCurrencyCode: Code[10];
        InstallmentCount: Integer;
        RemainingSubTotal: Decimal;
    begin
        if not SalesInvHeader.Get(InvoiceNo) then
            Error('Posted Sales Invoice %1 was not found.', InvoiceNo);

        if not SalesInvHeader."Installments Applied" then
            Error('No installments have been applied to invoice %1.', InvoiceNo);

        SavedInstallmentCode := SalesInvHeader."Installment Code Applied";
        SavedCurrencyCode := SalesInvHeader."Currency Code";

        SubCLE.SetRange("Customer No.", CustomerNo);
        SubCLE.SetFilter("Document No.", InvoiceNo + '-I*');
        SubCLE.SetRange("Document Type", SubCLE."Document Type"::Invoice);
        InstallmentCount := SubCLE.Count() + 1;

        if SubCLE.FindSet() then
            repeat
                SubDCLE.SetRange("Cust. Ledger Entry No.", SubCLE."Entry No.");
                SubDCLE.SetFilter("Entry Type", '<>%1', SubDCLE."Entry Type"::"Initial Entry");
                if not SubDCLE.IsEmpty() then
                    Error('Installment entry ''%1'' has payments applied to it. Reverse the payment before resetting installments.', SubCLE."Document No.");

                SubCLE.CalcFields("Remaining Amount");
                RemainingSubTotal += SubCLE."Remaining Amount";
            until SubCLE.Next() = 0;

        OrigCLE.SetRange("Document Type", OrigCLE."Document Type"::Invoice);
        OrigCLE.SetRange("Document No.", InvoiceNo);
        OrigCLE.SetRange("Customer No.", CustomerNo);
        if not OrigCLE.FindFirst() then
            Error('Original customer ledger entry for invoice %1 was not found.', InvoiceNo);

        // Close installment entries using standard journal posting
        if RemainingSubTotal <> 0 then begin
            EnsureInstallmentJournal();
            ClearInstallmentJournalLines();
            InsertResetClosingLineForInstallments(InvoiceNo, CustomerNo, SalesInvHeader);
            InsertResetReopenOriginalLine(OrigCLE, SalesInvHeader, RemainingSubTotal);
            PostInstallmentJournalLines();
        end;

        // Delete sub-entry invoice CLEs only after their balance has been closed
        SubCLE.SetRange("Customer No.", CustomerNo);
        SubCLE.SetFilter("Document No.", InvoiceNo + '-I*');
        SubCLE.SetRange("Document Type", SubCLE."Document Type"::Invoice);
        if SubCLE.FindSet() then
            repeat
                SubDCLE.SetRange("Cust. Ledger Entry No.", SubCLE."Entry No.");
                SubDCLE.DeleteAll();
            until SubCLE.Next() = 0;

        SubCLE.SetRange("Customer No.", CustomerNo);
        SubCLE.SetFilter("Document No.", InvoiceNo + '-I*');
        SubCLE.SetRange("Document Type", SubCLE."Document Type"::Invoice);
        SubCLE.DeleteAll();

        OrigCLE."Original Posted Amount" := 0;
        OrigCLE."Original Posted Amount (LCY)" := 0;
        OrigCLE.Description := CopyStr(StrSubstNo('Invoice %1', InvoiceNo), 1, 100);
        OrigCLE.Modify();

        SalesInvHeader."Installments Applied" := false;
        SalesInvHeader."Installment Code Applied" := '';
        SalesInvHeader.Modify();

        WriteLog(
            InvoiceNo, CustomerNo, SavedInstallmentCode,
            RemainingSubTotal, InstallmentCount, SavedCurrencyCode, 1);
    end;

    local procedure CreateJournalSplit(
        OrigCLE: Record "Cust. Ledger Entry";
        SalesInvHeader: Record "Sales Invoice Header";
        InstallmentTerms: Record "Installment Payment Terms";
        OriginalAmount: Decimal;
        OriginalAmountLCY: Decimal;
        RemainingAmount: Decimal;
        RemainingAmountLCY: Decimal)
    var
        InstallmentLine: Record "Installment Terms Line";
    begin
        InsertClosingJournalLine(OrigCLE, SalesInvHeader, RemainingAmount);

        InstallmentLine.SetRange("Code", InstallmentTerms.Code);
        if InstallmentLine.Count() >= 2 then
            CreatePercentageInstallmentLines(
                OrigCLE, SalesInvHeader, InstallmentTerms,
                OriginalAmount, OriginalAmountLCY,
                RemainingAmount, RemainingAmountLCY)
        else
            CreateEqualInstallmentLines(
                OrigCLE, SalesInvHeader, InstallmentTerms,
                OriginalAmount, OriginalAmountLCY,
                RemainingAmount, RemainingAmountLCY);
    end;

    local procedure CreatePercentageInstallmentLines(
        OrigCLE: Record "Cust. Ledger Entry";
        SalesInvHeader: Record "Sales Invoice Header";
        InstallmentTerms: Record "Installment Payment Terms";
        OriginalAmount: Decimal;
        OriginalAmountLCY: Decimal;
        RemainingAmount: Decimal;
        RemainingAmountLCY: Decimal)
    var
        InstallmentLine: Record "Installment Terms Line";
        LineAmount: Decimal;
        AccAmt: Decimal;
        DueDate: Date;
        LineCount: Integer;
        CurrentLine: Integer;
    begin
        InstallmentLine.SetRange("Code", InstallmentTerms.Code);
        InstallmentLine.SetCurrentKey("Code", "Installment No.");
        LineCount := InstallmentLine.Count();
        CurrentLine := 0;

        if not InstallmentLine.FindSet() then
            exit;

        repeat
            CurrentLine += 1;
            DueDate := CalcDate(
                StrSubstNo('<%1D>', InstallmentLine."Days from Posting Date"),
                OrigCLE."Posting Date");

            if CurrentLine = LineCount then
                LineAmount := RemainingAmount - AccAmt
            else begin
                LineAmount := Round(RemainingAmount * InstallmentLine.Percentage / 100, 0.01);
                AccAmt += LineAmount;
            end;

            InsertInstallmentJournalLine(
                OrigCLE, SalesInvHeader, LineAmount, DueDate,
                CurrentLine, LineCount, OriginalAmount, OriginalAmountLCY);
        until InstallmentLine.Next() = 0;
    end;

    local procedure CreateEqualInstallmentLines(
        OrigCLE: Record "Cust. Ledger Entry";
        SalesInvHeader: Record "Sales Invoice Header";
        InstallmentTerms: Record "Installment Payment Terms";
        OriginalAmount: Decimal;
        OriginalAmountLCY: Decimal;
        RemainingAmount: Decimal;
        RemainingAmountLCY: Decimal)
    var
        InstallmentAmt: Decimal;
        Remainder: Decimal;
        DueDate: Date;
        i: Integer;
        N: Integer;
        ThisAmount: Decimal;
    begin
        N := InstallmentTerms."No. of Installments";
        if N <= 1 then
            exit;

        InstallmentAmt := Round(RemainingAmount / N, 0.01);
        Remainder := RemainingAmount - (InstallmentAmt * N);

        DueDate := OrigCLE."Due Date";

        for i := 1 to N do begin
            ThisAmount := InstallmentAmt;
            if i = N then
                ThisAmount += Remainder;

            if i > 1 then
                DueDate := CalcDate(StrSubstNo('<%1D>', InstallmentTerms."Days Between Installments"), DueDate);

            InsertInstallmentJournalLine(
                OrigCLE, SalesInvHeader, ThisAmount, DueDate,
                i, N, OriginalAmount, OriginalAmountLCY);
        end;
    end;

    local procedure InsertClosingJournalLine(
    OrigCLE: Record "Cust. Ledger Entry";
    SalesInvHeader: Record "Sales Invoice Header";
    RemainingAmount: Decimal)
    var
        GenJnlLine: Record "Gen. Journal Line";
    begin
        InitJournalLine(GenJnlLine);

        GenJnlLine."Posting Date" := WorkDate();
        // GenJnlLine."Document Type" := GenJnlLine."Document Type"::Payment;//recheck
        GenJnlLine."Document Type" := GenJnlLine."Document Type"::"Credit Memo";
        GenJnlLine."Document No." := CopyStr(SalesInvHeader."No." + '-CLS', 1, 20);
        GenJnlLine."Account Type" := GenJnlLine."Account Type"::Customer;
        GenJnlLine."Account No." := OrigCLE."Customer No.";

        SetJournalCurrencyFromCustLedger(GenJnlLine, OrigCLE);
        genjnlline.Validate("Dimension Set ID", OrigCLE."Dimension Set ID");
        genjnlline.Validate("Salespers./Purch. Code", OrigCLE."Salesperson Code");
        GenJnlLine.validate("External Document No.", OrigCLE."External Document No.");
        GenJnlLine.Validate(Amount, -RemainingAmount);
        GenJnlLine."Applies-to Doc. Type" := GenJnlLine."Applies-to Doc. Type"::Invoice;
        GenJnlLine."Applies-to Doc. No." := SalesInvHeader."No.";
        GenJnlLine."Bal. Account Type" := GenJnlLine."Bal. Account Type"::"G/L Account";
        GenJnlLine."Bal. Account No." := GetClearingAccountNo(SalesInvHeader);
        GenJnlLine.Description := CopyStr(StrSubstNo('Close invoice %1 for installment split', SalesInvHeader."No."), 1, 100);
        GenJnlLine.Insert(true);
    end;

    local procedure InsertInstallmentJournalLine(
    OrigCLE: Record "Cust. Ledger Entry";
    SalesInvHeader: Record "Sales Invoice Header";
    InstallmentAmount: Decimal;
    DueDate: Date;
    InstallmentNo: Integer;
    TotalInstallments: Integer;
    OriginalAmount: Decimal;
    OriginalAmountLCY: Decimal)
    var
        GenJnlLine: Record "Gen. Journal Line";
    begin
        InitJournalLine(GenJnlLine);

        GenJnlLine."Posting Date" := WorkDate();
        GenJnlLine."Document Type" := GenJnlLine."Document Type"::Invoice;
        GenJnlLine."Document No." := CopyStr(SalesInvHeader."No." + '-I' + Format(InstallmentNo), 1, 20);
        GenJnlLine."Account Type" := GenJnlLine."Account Type"::Customer;
        GenJnlLine."Account No." := OrigCLE."Customer No.";

        SetJournalCurrencyFromCustLedger(GenJnlLine, OrigCLE);
        genjnlline.Validate("Dimension Set ID", OrigCLE."Dimension Set ID");
        genjnlline.Validate("Salespers./Purch. Code", OrigCLE."Salesperson Code");
        GenJnlLine.validate("External Document No.", OrigCLE."External Document No.");
        GenJnlLine.Validate(Amount, InstallmentAmount);
        GenJnlLine."Due Date" := DueDate;
        GenJnlLine."Bal. Account Type" := GenJnlLine."Bal. Account Type"::"G/L Account";
        GenJnlLine."Bal. Account No." := GetClearingAccountNo(SalesInvHeader);
        GenJnlLine.Description := CopyStr(
            StrSubstNo('Installment %1/%2 - %3', InstallmentNo, TotalInstallments, SalesInvHeader."No."), 1, 100);
        GenJnlLine.Insert(true);
    end;

    local procedure InsertResetClosingLineForInstallments(InvoiceNo: Code[20]; CustomerNo: Code[20]; SalesInvHeader: Record "Sales Invoice Header")
    var
        SubCLE: Record "Cust. Ledger Entry";
        GenJnlLine: Record "Gen. Journal Line";
    begin
        SubCLE.SetRange("Customer No.", CustomerNo);
        SubCLE.SetFilter("Document No.", InvoiceNo + '-I*');
        SubCLE.SetRange("Document Type", SubCLE."Document Type"::Invoice);

        if SubCLE.FindSet() then
            repeat
                SubCLE.CalcFields("Remaining Amount", "Remaining Amt. (LCY)");
                if SubCLE."Remaining Amount" <> 0 then begin
                    InitJournalLine(GenJnlLine);
                    GenJnlLine."Posting Date" := WorkDate();
                    // GenJnlLine."Document Type" := GenJnlLine."Document Type"::Payment;//recheck
                    GenJnlLine."Document Type" := GenJnlLine."Document Type"::"Credit Memo";
                    GenJnlLine."Document No." := CopyStr(SubCLE."Document No." + '-RST', 1, 20);
                    GenJnlLine."Account Type" := GenJnlLine."Account Type"::Customer;
                    GenJnlLine."Account No." := CustomerNo;

                    SetJournalCurrencyFromCustLedger(GenJnlLine, SubCLE);
                    GenJnlLine.Validate("Dimension Set ID", SubCLE."Dimension Set ID");
                    GenJnlLine.Validate("Salespers./Purch. Code", SubCLE."Salesperson Code");
                    GenJnlLine.Validate("External Document No.", SubCLE."External Document No.");
                    GenJnlLine.Validate(Amount, -SubCLE."Remaining Amount");
                    GenJnlLine."Applies-to Doc. Type" := GenJnlLine."Applies-to Doc. Type"::Invoice;
                    GenJnlLine."Applies-to Doc. No." := SubCLE."Document No.";
                    GenJnlLine."Bal. Account Type" := GenJnlLine."Bal. Account Type"::"G/L Account";
                    GenJnlLine."Bal. Account No." := GetClearingAccountNo(SalesInvHeader);
                    GenJnlLine.Description := CopyStr(StrSubstNo('Reset installment %1', SubCLE."Document No."), 1, 100);
                    GenJnlLine.Insert(true);
                end;
            until SubCLE.Next() = 0;
    end;

    local procedure InsertResetReopenOriginalLine(
    OrigCLE: Record "Cust. Ledger Entry";
    SalesInvHeader: Record "Sales Invoice Header";
    RemainingSubTotal: Decimal)
    var
        GenJnlLine: Record "Gen. Journal Line";
    begin
        InitJournalLine(GenJnlLine);

        GenJnlLine."Posting Date" := WorkDate();
        GenJnlLine."Document Type" := GenJnlLine."Document Type"::Invoice;
        GenJnlLine."Document No." := CopyStr(SalesInvHeader."No." + '-RSTR', 1, 20);
        GenJnlLine."Account Type" := GenJnlLine."Account Type"::Customer;
        GenJnlLine."Account No." := OrigCLE."Customer No.";

        // SetJournalCurrencyFromCustLedger(GenJnlLine, OrigCLE);//recheck
        genjnlline.Validate("Currency Code", OrigCLE."Currency Code");//recheck
        GenJnlLine.Validate("Dimension Set ID", OrigCLE."Dimension Set ID");
        GenJnlLine.Validate("Salespers./Purch. Code", OrigCLE."Salesperson Code");
        GenJnlLine.validate("External Document No.", OrigCLE."External Document No.");
        GenJnlLine.Validate(Amount, RemainingSubTotal);
        GenJnlLine."Due Date" := SalesInvHeader."Due Date";
        GenJnlLine."Bal. Account Type" := GenJnlLine."Bal. Account Type"::"G/L Account";
        GenJnlLine."Bal. Account No." := GetClearingAccountNo(salesInvHeader);
        GenJnlLine.Description := CopyStr(StrSubstNo('Restore invoice %1', SalesInvHeader."No."), 1, 100);
        GenJnlLine.Insert(true);
    end;

    local procedure StampOriginalPostedAmounts(InvoiceNo: Code[20]; CustomerNo: Code[20]; OriginalAmount: Decimal; OriginalAmountLCY: Decimal)
    var
        CustLedgEntry: Record "Cust. Ledger Entry";
    begin
        CustLedgEntry.SetRange("Customer No.", CustomerNo);
        CustLedgEntry.SetFilter("Document No.", InvoiceNo + '|' + InvoiceNo + '-I*');
        CustLedgEntry.SetRange("Document Type", CustLedgEntry."Document Type"::Invoice);

        if CustLedgEntry.FindSet() then
            repeat
                CustLedgEntry."Original Posted Amount" := OriginalAmount;
                CustLedgEntry."Original Posted Amount (LCY)" := OriginalAmountLCY;
                CustLedgEntry.Modify();
            until CustLedgEntry.Next() = 0;
    end;

    local procedure InitJournalLine(var GenJnlLine: Record "Gen. Journal Line")
    begin
        GenJnlLine.Init();
        GenJnlLine."Journal Template Name" := GetJournalTemplateName();
        GenJnlLine."Journal Batch Name" := GetJournalBatchName();
        GenJnlLine."Line No." := GetNextGenJnlLineNo();
    end;

    local procedure PostInstallmentJournalLines()
    var
        GenJnlLine: Record "Gen. Journal Line";
        GenJnlPostBatch: Codeunit "Gen. Jnl.-Post Batch";
    begin
        GenJnlLine.SetRange("Journal Template Name", GetJournalTemplateName());
        GenJnlLine.SetRange("Journal Batch Name", GetJournalBatchName());
        if GenJnlLine.IsEmpty() then
            exit;

        GenJnlPostBatch.Run(GenJnlLine);
    end;

    local procedure ClearInstallmentJournalLines()
    var
        GenJnlLine: Record "Gen. Journal Line";
    begin
        GenJnlLine.SetRange("Journal Template Name", GetJournalTemplateName());
        GenJnlLine.SetRange("Journal Batch Name", GetJournalBatchName());
        if not GenJnlLine.IsEmpty() then
            GenJnlLine.DeleteAll();
    end;

    local procedure EnsureInstallmentJournal()
    var
        GenJnlTemplate: Record "Gen. Journal Template";
        GenJnlBatch: Record "Gen. Journal Batch";
    begin
        if not GenJnlTemplate.Get(GetJournalTemplateName()) then
            Error('Journal Template %1 does not exist. Create it first.', GetJournalTemplateName());

        if not GenJnlBatch.Get(GetJournalTemplateName(), GetJournalBatchName()) then begin
            GenJnlBatch.Init();
            GenJnlBatch."Journal Template Name" := GetJournalTemplateName();
            GenJnlBatch.Name := GetJournalBatchName();
            GenJnlBatch.Description := 'Installment split journal';
            GenJnlBatch.Insert(true);
        end;
    end;

    local procedure GetNextGenJnlLineNo(): Integer
    var
        GenJnlLine: Record "Gen. Journal Line";
    begin
        GenJnlLine.SetRange("Journal Template Name", GetJournalTemplateName());
        GenJnlLine.SetRange("Journal Batch Name", GetJournalBatchName());
        if GenJnlLine.FindLast() then
            exit(GenJnlLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure GetJournalTemplateName(): Code[10]
    begin
        exit('GENERAL');//TODO: open a new field for this
    end;

    local procedure GetJournalBatchName(): Code[10]
    var
        SalesSetup: Record "Sales & Receivables Setup";
    begin
        if SalesSetup.Get() then
            exit(SalesSetup."Installment Batch Name");
    end;

    local procedure GetClearingAccountNo(SalesInvHeader: Record "Sales Invoice Header"): Code[20]
    var
        SalesSetup: Record "Sales & Receivables Setup";
    begin
        SalesSetup.Get();

        if HasVAT(SalesInvHeader) then begin
            SalesSetup.TestField("Installment Bal. Acc. VAT");
            exit(SalesSetup."Installment Bal. Acc. VAT");
        end else begin
            SalesSetup.TestField(SalesSetup."Installement Bal. Acc.");
            exit(SalesSetup."Installement Bal. Acc.");
        end;
    end;

    local procedure HasVAT(SalesInvHeader: Record "Sales Invoice Header"): Boolean
    begin
        exit(SalesInvHeader."Amount Including VAT" <> SalesInvHeader.Amount);
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

    local procedure SetJournalCurrencyFromCustLedger(var GenJnlLine: Record "Gen. Journal Line"; OrigCLE: Record "Cust. Ledger Entry")
    begin
        GenJnlLine."Currency Code" := OrigCLE."Currency Code";

        if OrigCLE."Currency Code" = '' then
            GenJnlLine."Currency Factor" := 0
        else
            if OrigCLE."Remaining Amount" <> 0 then
                // GenJnlLine."Currency Factor" := Round(OrigCLE."Remaining Amount" / OrigCLE."Remaining Amt. (LCY)", 0.0000001)
                GenJnlLine."Currency Factor" := OrigCLE."Remaining Amount" / OrigCLE."Remaining Amt. (LCY)"
            else if OrigCLE.Amount <> 0 then
                // GenJnlLine."Currency Factor" := Round(OrigCLE.Amount / OrigCLE."Amount (LCY)", 0.0000001)
                GenJnlLine."Currency Factor" := OrigCLE.Amount / OrigCLE."Amount (LCY)"
            else
                GenJnlLine."Currency Factor" := 1;
    end;
}