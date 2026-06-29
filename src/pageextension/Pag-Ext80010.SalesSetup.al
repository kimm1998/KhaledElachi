pageextension 80010 SalesSetupExt extends "Sales & Receivables Setup"
{
    layout
    {
        // Add changes to page layout here
        addlast(General)
        {
            field("Installement Bal. Acc."; Rec."Installement Bal. Acc.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the balancing account for installment payments.';
            }
            field("Installment Batch Name"; Rec."Installment Batch Name")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the batch name for installment payment journals.';
            }
            field("Installment Bal. Acc. VAT"; Rec."Installment Bal. Acc. VAT")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the balancing account for VAT on installment payments.';
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
}