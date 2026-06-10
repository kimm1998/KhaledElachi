pageextension 80002 CustomerExt extends "Customer Card"
{
    layout
    {
        addafter(General)
        {
            group(CreditExposureGrp)
            {
                Caption = 'Credit Exposure';

                field(ReturnsNotInvoicedCtrl; ReturnsNotInvoicedLCY)
                {
                    ApplicationArea = All;
                    Caption = 'Returns Not Invoiced (LCY)';
                    DecimalPlaces = 2 : 2;
                    Editable = false;
                    ToolTip = 'Total LCY amount of return orders that have been shipped back to you but whose credit memo has not yet been posted for this customer.';
                }
                field(ExposureCtrl; ExposureLCY)
                {
                    ApplicationArea = All;
                    Caption = 'Exposure (LCY)';
                    DecimalPlaces = 2 : 2;
                    Editable = false;
                    StyleExpr = ExposureStyleExpr;
                    ToolTip = 'Customer credit exposure = Balance (LCY) + Shipped Not Invoiced (LCY) − Returns Not Invoiced (LCY). Displayed in red when it exceeds the credit limit.';
                }
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    trigger OnAfterGetCurrRecord()
    begin
        CalcCreditExposureFields();
        CurrPage.Update(); // Ensure the fields are updated when the page opens
    end;
     trigger OnAfterGetRecord()
    begin
        CalcCreditExposureFields();
        CurrPage.Update(); // Ensure the fields are updated when the page opens
    end;
     trigger OnOpenPage()
    begin
        CalcCreditExposureFields();
        CurrPage.Update(); // Ensure the fields are updated when the page opens
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
            SalesCreditLimitMgmt.CalcReturnsNotInvoicedLCY(Rec."No.");
        ExposureLCY :=
            SalesCreditLimitMgmt.CalcExposureLCY(Rec."No.");

        ExposureStyleExpr := 'Standard';
        if Customer.Get(Rec."No.") then
            if (Customer."Credit Limit (LCY)" <> 0) and
               (ExposureLCY > Customer."Credit Limit (LCY)")
            then
                ExposureStyleExpr := 'Unfavorable'; // shown in red
    end;
}