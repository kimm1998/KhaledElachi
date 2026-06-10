codeunit 80000 "Sales Credit Limit Mgmt."
{
    /// <summary>
    /// Calculates the total LCY value of sales return order lines that have been
    /// shipped (goods received back) but whose credit memo has not yet been posted.
    /// Mirrors the logic of "Shipped Not Invoiced (LCY)" on Customer, but for returns.
    /// </summary>
    procedure CalcReturnsNotInvoicedLCY(BillToCustomerNo: Code[20]): Decimal
    var
        SalesLine: Record "Sales Line";
        SalesHeader: Record "Sales Header";
        CurrExchRate: Record "Currency Exchange Rate";
        TotalLCY: Decimal;
        LineAmtLCY: Decimal;
    begin
        if BillToCustomerNo = '' then
            exit(0);

        SalesLine.Reset();
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::"Return Order");
        SalesLine.SetRange("Bill-to Customer No.", BillToCustomerNo);
        SalesLine.SetFilter("Return Qty. Rcd. Not Invd.", '>0');
        if SalesLine.FindSet() then
            repeat
                // Amount = qty returned (shipped back) not yet credit-memos'd × unit price × (1 - line discount)
                LineAmtLCY :=
                    SalesLine."Return Qty. Rcd. Not Invd." *
                    SalesLine."Unit Price" *
                    (1 - SalesLine."Line Discount %" / 100);

                // Convert to LCY if the return order is in a foreign currency
                if SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.") then
                    if SalesHeader."Currency Code" <> '' then
                        LineAmtLCY := CurrExchRate.ExchangeAmtFCYToLCY(
                            WorkDate(),
                            SalesHeader."Currency Code",
                            LineAmtLCY,
                            SalesHeader."Currency Factor");

                TotalLCY += LineAmtLCY;
            until SalesLine.Next() = 0;

        exit(TotalLCY);
    end;

    /// <summary>
    /// Exposure = Balance (LCY) + Shipped Not Invoiced (LCY) - Returns Not Invoiced (LCY)
    /// </summary>
    procedure CalcExposureLCY(BillToCustomerNo: Code[20]): Decimal
    var
        Customer: Record Customer;
    begin
        if BillToCustomerNo = '' then
            exit(0);

        Customer.Get(BillToCustomerNo);
        Customer.CalcFields("Balance (LCY)", "Shipped Not Invoiced (LCY)");

        exit(
            Customer."Balance (LCY)" +
            Customer."Shipped Not Invoiced (LCY)" -
            CalcReturnsNotInvoicedLCY(BillToCustomerNo));
    end;


}