pageextension 80003 "Purch. Order Ext" extends "Purchase Order"
{
    layout
    {
        addbefore("Prepayment %")
        {
            field("Requested Prepay Amt Incl. VAT"; Rec."Requested Prepay Amt Incl. VAT")
            {
                ApplicationArea = All;
                ToolTip = 'Enter the desired prepayment amount including VAT. The system will calculate Prepayment % based on the order total including VAT.';
            }

            // field("Prepay Paid Amount"; Rec."Prepay Paid Amount")
            // {
            //     ApplicationArea = All;
            //     ToolTip = 'Shows the amount of payments applied to posted prepayment invoice(s) for this order (document currency).';
            // }
        }
    }

    actions
    {
        addlast(Processing)
        {
            action(RecalcPrepayPaid)
            {
                Caption = 'Recalculate Prepayment Paid';
                ApplicationArea = All;
                Image = Calculate;
                visible = false;

                trigger OnAction()
                begin
                    Rec.RecalculatePrepayPaidAmount();
                    CurrPage.Update(false);
                end;
            }
        }
    }
}