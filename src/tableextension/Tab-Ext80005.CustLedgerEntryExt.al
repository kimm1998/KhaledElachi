tableextension 80005 "Cust. Ledger Entry Ext" extends "Cust. Ledger Entry"
{
    fields
    {
        // Stores the full original invoice amount (Amt. Incl. VAT) at time of posting.
        // Never changes after being set — survives installment splits and partial payments.
        // Identical across all installment CLE entries for the same invoice.
        field(80010; "Original Posted Amount"; Decimal)
        {
            Caption = 'Original Posted Amount';
            DataClassification = CustomerContent;
        }
        field(80011; "Original Posted Amount (LCY)"; Decimal)
        {
            Caption = 'Original Posted Amount (LCY)';
            DataClassification = CustomerContent;
        }
    }
}