page 80007 "Apply Installment Terms"
{
    Caption = 'Apply Installment Terms';
    PageType = Card;
    DataCaptionExpression = DocumentNo;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(InvoiceInfo)
            {
                Caption = 'Invoice Information';
                field(DocumentNoField; DocumentNo)
                {
                    ApplicationArea = All;
                    Caption = 'Invoice No.';
                    Editable = false;
                }
                field(CustomerNoField; CustomerNo)
                {
                    ApplicationArea = All;
                    Caption = 'Customer No.';
                    Editable = false;
                }
                field(RemainingAmountField; RemainingAmount)
                {
                    ApplicationArea = All;
                    Caption = 'Remaining Amount to Split';
                    Editable = false;
                }
                field(CurrencyCodeField; CurrencyCode)
                {
                    ApplicationArea = All;
                    Caption = 'Currency';
                    Editable = false;
                }
            }
            group(Setup)
            {
                Caption = 'Select Installment Terms';
                field(InstallmentCodeField; SelectedInstallmentCode)
                {
                    ApplicationArea = All;
                    Caption = 'Installment Code';
                    TableRelation = "Installment Payment Terms".Code;

                    trigger OnValidate()
                    begin
                        RefreshPreview();
                    end;
                }
            }
            part(PreviewPart; "Installment Preview Lines")
            {
                ApplicationArea = All;
                Caption = 'Payment Schedule Preview';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ApplyInstallments)
            {
                Caption = 'Apply Installments';
                Image = Apply;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Apply the selected installment terms and split this invoice into multiple payment entries.';

                trigger OnAction()
                var
                    InstallmentApply: Codeunit "Installment Apply to Posted";
                    InstallmentCount: Integer;
                begin
                    if SelectedInstallmentCode = '' then
                        Error('Please select an Installment Code before applying.');

                    InstallmentCount := GetInstallmentCount();
                    if InstallmentCount < 2 then
                        Error('The selected Installment Code must have at least 2 installments.');

                    if not Confirm(
                        'Apply installment code ''%1'' to invoice %2?This will split the remaining amount of %3 %4 into %5 installments.Continue?',
                        true,
                        SelectedInstallmentCode, DocumentNo,
                        RemainingAmount, CurrencyCode, InstallmentCount)
                    then
                        exit;

                    InstallmentApply.ApplyToPostedInvoice(DocumentNo, CustomerNo, SelectedInstallmentCode);
                    Applied := true;
                    Message('Installment terms ''%1'' successfully applied to invoice %2.', SelectedInstallmentCode, DocumentNo);
                    CurrPage.Close();
                end;
            }
        }
    }

    var
        DocumentNo: Code[20];
        CustomerNo: Code[20];
        RemainingAmount: Decimal;
        CurrencyCode: Code[10];
        PostingDate: Date;
        SelectedInstallmentCode: Code[20];
        Applied: Boolean;

    procedure SetContext(DocNo: Code[20]; CustNo: Code[20]; RemAmt: Decimal; CurrCode: Code[10]; PDate: Date)
    begin
        DocumentNo := DocNo;
        CustomerNo := CustNo;
        RemainingAmount := RemAmt;
        CurrencyCode := CurrCode;
        PostingDate := PDate;
    end;

    procedure WasApplied(): Boolean
    begin
        exit(Applied);
    end;

    local procedure RefreshPreview()
    var
        InstallmentTerms: Record "Installment Payment Terms";
        InstallmentLine: Record "Installment Terms Line";
        TempPreviewLine: Record "Installment Preview Line" temporary;
        LineAmt: Decimal;
        AccAmt: Decimal;
        LineNo: Integer;
        N: Integer;
        DueDate: Date;
    begin
        TempPreviewLine.DeleteAll();

        if SelectedInstallmentCode = '' then begin
            CurrPage.PreviewPart.Page.LoadLines(TempPreviewLine);
            exit;
        end;

        if not InstallmentTerms.Get(SelectedInstallmentCode) then exit;

        InstallmentLine.SetRange("Code", SelectedInstallmentCode);
        InstallmentLine.SetCurrentKey("Code", "Installment No.");

        if InstallmentLine.Count() >= 2 then begin
            // Percentage mode
            N := InstallmentLine.Count();
            LineNo := 1;
            AccAmt := 0;
            if InstallmentLine.FindSet() then
                repeat
                    TempPreviewLine.Init();
                    TempPreviewLine."Line No." := LineNo * 10000;
                    TempPreviewLine."Installment No." := LineNo;
                    TempPreviewLine.Percentage := InstallmentLine.Percentage;
                    DueDate := CalcDate(StrSubstNo('<%1D>', InstallmentLine."Days from Posting Date"), PostingDate);
                    TempPreviewLine."Due Date" := DueDate;

                    if LineNo = N then
                        LineAmt := RemainingAmount - AccAmt
                    else begin
                        LineAmt := Round(RemainingAmount * InstallmentLine.Percentage / 100, 0.01);
                        AccAmt += LineAmt;
                    end;

                    TempPreviewLine.Amount := LineAmt;
                    TempPreviewLine.Description := StrSubstNo('Installment %1/%2 - %3', LineNo, N, DocumentNo);
                    TempPreviewLine.Insert();
                    LineNo += 1;
                until InstallmentLine.Next() = 0;
        end else begin
            // Equal split mode
            N := InstallmentTerms."No. of Installments";
            if N <= 1 then exit;

            LineAmt := Round(RemainingAmount / N, 0.01);
            AccAmt := 0;

            for LineNo := 1 to N do begin
                TempPreviewLine.Init();
                TempPreviewLine."Line No." := LineNo * 10000;
                TempPreviewLine."Installment No." := LineNo;
                TempPreviewLine.Percentage := Round(100 / N, 0.01);
                DueDate := CalcDate(
                    StrSubstNo('<%1D>', InstallmentTerms."Days Between Installments" * LineNo),
                    PostingDate);
                TempPreviewLine."Due Date" := DueDate;

                if LineNo = N then
                    TempPreviewLine.Amount := RemainingAmount - AccAmt
                else begin
                    TempPreviewLine.Amount := LineAmt;
                    AccAmt += LineAmt;
                end;

                TempPreviewLine.Description := StrSubstNo('Installment %1/%2 - %3', LineNo, N, DocumentNo);
                TempPreviewLine.Insert();
            end;
        end;

        CurrPage.PreviewPart.Page.LoadLines(TempPreviewLine);
    end;

    local procedure GetInstallmentCount(): Integer
    var
        InstallmentTerms: Record "Installment Payment Terms";
        InstallmentLine: Record "Installment Terms Line";
    begin
        if not InstallmentTerms.Get(SelectedInstallmentCode) then exit(0);
        InstallmentLine.SetRange("Code", SelectedInstallmentCode);
        if InstallmentLine.Count() >= 2 then
            exit(InstallmentLine.Count());
        exit(InstallmentTerms."No. of Installments");
    end;
}