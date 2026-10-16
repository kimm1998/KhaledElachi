pageextension 80000 "Sales Order Credit Ext." extends "Sales Order"
{
    layout
    {
        addlast(content)
        {
            group(CreditExposureGrp)
            {
                Caption = 'Credit Exposure';
                Visible = false;

                field(ReturnsNotInvoicedCtrl; ReturnsNotInvoicedLCY)
                {
                    ApplicationArea = All;
                    Caption = 'Returns Not Invoiced (LCY)';
                    Editable = false;
                    ToolTip = 'Total LCY amount of return orders that have been shipped back to you but whose credit memo has not yet been posted for this customer.';
                }
                field(ExposureCtrl; ExposureLCY)
                {
                    ApplicationArea = All;
                    Caption = 'Exposure (LCY)';
                    Editable = false;
                    DecimalPlaces = 2 : 2;
                    StyleExpr = ExposureStyleExpr;
                    ToolTip = 'Customer credit exposure = Balance (LCY) + Shipped Not Invoiced (LCY) − Returns Not Invoiced (LCY). Displayed in red when it exceeds the credit limit.';
                }
            }
        }
        // addafter("Payment Terms Code")//installemnt //toremove
        // {
        //     field("Installment Code"; Rec."Installment Code")
        //     {
        //         ApplicationArea = All;
        //         Caption = 'Installment Code';
        //         ToolTip = 'Specifies the installment schedule for this sale.';
        //     }
        // }
        // modify("Payment Terms Code")//installemnt
        // {
        //     trigger OnAfterValidate()
        //     var
        //         PaymentTerms: Record "Payment Terms";
        //     begin
        //         if PaymentTerms.Get(Rec."Payment Terms Code") then
        //             Rec."Installment Code" := PaymentTerms."Installment Code";
        //     end;
        // }
    }

    trigger OnAfterGetRecord()
    Var
        SalesCrLimitCheck: Codeunit "Sales Credit Limit Check";
    begin
        // CalcCreditExposureFields();
        SalesCrLimitCheck.ValidateCreditLimitExeed(Rec);
    end;

    var
        ReturnsNotInvoicedLCY: Decimal;
        ExposureLCY: Decimal;
        ExposureStyleExpr: Text;

    local procedure CalcCreditExposureFields()
    var
        SalesCreditLimitMgmt: Codeunit "Sales Credit Limit Mgmt.";
        Customer: Record Customer;
    begin
        ReturnsNotInvoicedLCY :=
            SalesCreditLimitMgmt.CalcReturnsNotInvoicedLCY(Rec."Bill-to Customer No.");
        ExposureLCY :=
            SalesCreditLimitMgmt.CalcExposureLCY(Rec."Bill-to Customer No.");

        ExposureStyleExpr := 'Standard';
        if Customer.Get(Rec."Bill-to Customer No.") then
            if (Customer."Credit Limit (LCY)" <> 0) and
               (ExposureLCY > Customer."Credit Limit (LCY)")
            then
                ExposureStyleExpr := 'Unfavorable'; // shown in red
    end;
}