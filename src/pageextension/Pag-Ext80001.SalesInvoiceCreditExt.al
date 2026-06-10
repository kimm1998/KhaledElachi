pageextension 80001 "Sales Invoice Credit Ext." extends "Sales Invoice"
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
                    StyleExpr = ExposureStyleExpr;
                    ToolTip = 'Customer credit exposure = Balance (LCY) + Shipped Not Invoiced (LCY) − Returns Not Invoiced (LCY). Displayed in red when it exceeds the credit limit.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    Var 
    SalesCreditLimitCheck: Codeunit "Sales Credit Limit Check";
    begin
      CalcCreditExposureFields();
      SalesCreditLimitCheck.ValidateCreditLimitExeed(Rec);
        
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
                ExposureStyleExpr := 'Unfavorable';
    end;

}