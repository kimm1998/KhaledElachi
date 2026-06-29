pageextension 80008 "Cust. Ledger Entries Ext" extends "Customer Ledger Entries"
{
    layout
    {
        addafter("Original Amt. (LCY)")
        {
            field("Original Posted Amount"; Rec."Original Posted Amount")
            {
                ApplicationArea = All;
                Caption = 'Original Posted Amount';
                ToolTip = 'The full invoice amount (incl. VAT) at time of posting. This value is the same on all installment entries for the same invoice and never changes after posting.';
            }
            field("Original Posted Amount (LCY)"; Rec."Original Posted Amount (LCY)")
            {
                ApplicationArea = All;
                Caption = 'Original Posted Amount (LCY)';
                ToolTip = 'The full invoice amount (LCY) at time of posting.';
                Visible = false;
            }
        }
        modify("Original Amount")
        {
            caption = 'Entry Original Amount';
        }
    }
}