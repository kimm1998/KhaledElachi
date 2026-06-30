pageextension 80005 "Payment Terms Page Ext" extends "Payment Terms"
{
    layout
    {
        addafter(Description)
        {
            field("Installment Code"; Rec."Installment Code")
            {
                ApplicationArea = All;
                Caption = 'Installment Code';
                ToolTip = 'Select an installment schedule. When set, posted invoices will be split into multiple due date entries.';
            }
        }
    }
}