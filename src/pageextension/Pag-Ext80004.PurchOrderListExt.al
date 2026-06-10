pageextension 80004 "Purch. Order List Ext" extends "Purchase Order List"
{
    layout
    {
        addlast(Control1)
        {
            field("Prepay Paid Amount"; Rec."Prepay Paid Amount")
            {
                ApplicationArea = All;
                ToolTip = 'Prepayment paid amount (payments applied to posted prepayment invoices for this order).';
            }
        }
    }
    trigger OnAfterGetCurrRecord()
    var
        myInt: Integer;
    begin
        // rec.RecalculatePrepayPaidAmount();

    end;

    trigger OnOpenPage()
    var
        myInt: Integer;
        PurchHeader: Record "Purchase Header";
    begin
        PurchHeader.SetRange("Document Type", PurchHeader."Document Type"::Order);
        if PurchHeader.findset() then
            repeat
                PurchHeader.RecalculatePrepayPaidAmount();
        until PurchHeader.next() = 0;

    end;
}