codeunit 80014 "Order Appr. Request Webhook"
{
    // Posts sales order approval requests to the Google Apps Script endpoint.
    // Failures are silent by design (they never block the approval request).

    [EventSubscriber(ObjectType::Table, Database::"Approval Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertApprovalEntry(var Rec: Record "Approval Entry"; RunTrigger: Boolean)
    var
        SalesHeader: Record "Sales Header";
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."Table ID" <> Database::"Sales Header" then
            exit;
        if Rec."Document Type" <> Rec."Document Type"::Order then
            exit;
        // Only the approver who currently has to act (Open); not the queued (Created) ones.
        if Rec.Status <> Rec.Status::Open then
            exit;
        if not SalesHeader.Get(SalesHeader."Document Type"::Order, Rec."Document No.") then
            exit;

        if TrySendRequest(SalesHeader, Rec) then;
    end;

    [TryFunction]
    local procedure TrySendRequest(SalesHeader: Record "Sales Header"; ApprovalEntry: Record "Approval Entry")
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        HttpContent: HttpContent;
        HttpHeaders: HttpHeaders;
        WebhookUrl: Text;
    begin
        WebhookUrl := 'https://script.google.com/macros/s/AKfycbyooTRNZL1GdtJyds6JaryXkY8Hf_ZWZprWEHLiZUj3aTFwU-AGbmeFAYtvSYIPJ1Uu/exec';

        HttpContent.WriteFrom(BuildJson(SalesHeader, ApprovalEntry));
        HttpContent.GetHeaders(HttpHeaders);
        HttpHeaders.Clear();
        HttpHeaders.Add('Content-Type', 'application/json');

        HttpRequestMessage.Method := 'POST';
        HttpRequestMessage.SetRequestUri(WebhookUrl);
        HttpRequestMessage.Content := HttpContent;

        if HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then;
    end;

    local procedure BuildJson(SalesHeader: Record "Sales Header"; ApprovalEntry: Record "Approval Entry"): Text
    var
        Customer: Record Customer;
        CompanyInfo: Record "Company Information";
        CreditLimitMgmt: Codeunit "Sales Credit Limit Mgmt.";
        JObject: JsonObject;
        JData: JsonObject;
        JsonText: Text;
        CustomerNo: Code[20];
    begin
        CompanyInfo.Get();
        SalesHeader.CalcFields("Amount Including VAT");

        CustomerNo := SalesHeader."Bill-to Customer No.";
        if CustomerNo = '' then
            CustomerNo := SalesHeader."Sell-to Customer No.";

        JData.Add('orderLink', GetApprovalLink(ApprovalEntry));
        JData.Add('orderNumber', SalesHeader."No.");
        JData.Add('customerName', SalesHeader."Sell-to Customer Name");
        JData.Add('customerNumber', SalesHeader."Sell-to Customer No.");
        JData.Add('salesPersonCode', SalesHeader."Salesperson Code");
        JData.Add('orderTotal', Format(SalesHeader."Amount Including VAT", 0, 9));
        JData.Add('orderCurrency', GetCurrencyCode(SalesHeader));
        JData.Add('profit', Format(CalcProfit(SalesHeader), 0, 9));

        if Customer.Get(CustomerNo) then begin
            Customer.CalcFields("Balance Due (LCY)");
            JData.Add('customerOverdueAmount', Format(Customer."Balance Due (LCY)", 0, 9));
            JData.Add('customerTotalExposure', Format(CreditLimitMgmt.CalcExposureLCY(CustomerNo), 0, 9));
        end else begin
            JData.Add('customerOverdueAmount', '0');
            JData.Add('customerTotalExposure', '0');
        end;

        JData.Add('orderPaymentTerms', SalesHeader."Payment Terms Code");
        JData.Add('orderDueDate', Format(SalesHeader."Due Date", 0, 9));
        JData.Add('requestReason', GetRequestReason(SalesHeader));
        JData.Add('entity', CompanyInfo."API Country");

        JObject.Add('authToken', '8f3c1a9d-6b72-4c5e-91a0-3d7f2c9e5b44');
        JObject.Add('requestType', 'request_order_approval');
        JObject.Add('data', JData);

        JObject.WriteTo(JsonText);
        exit(JsonText);
    end;

    /// <summary>
    /// Reason for the approval request, based on the same checks that block posting
    /// (Sales Credit Limit Check -> ValidateCreditLimitExeed). SalesHeader is passed by value,
    /// so the flags calculated here are never saved to the database.
    /// </summary>
    local procedure GetRequestReason(SalesHeader: Record "Sales Header"): Text
    var
        CreditLimitCheck: Codeunit "Sales Credit Limit Check";
        Reason: Text;
    begin
        CreditLimitCheck.ValidateCreditLimitExeed(SalesHeader);

        if SalesHeader."Overdue Exceeded" then
            Reason := OverdueBalanceTxt;
        if SalesHeader."Exposure Exceeds Credit Limit" then
            Reason := AppendReason(Reason, ExposureExceedsTxt);
        if SalesHeader."Balance Exceeds Credit Limit" then
            Reason := AppendReason(Reason, BalanceExceedsTxt);

        if Reason = '' then
            Reason := ManualRequestTxt;
        exit(Reason);
    end;

    local procedure AppendReason(Reason: Text; NewReason: Text): Text
    begin
        if Reason = '' then
            exit(NewReason);
        exit(Reason + '; ' + NewReason);
    end;

    /// <summary>
    /// Profit in the ORDER currency: sum(Line Amount) - sum(Unit Cost (LCY) * Qty) converted LCY -> order currency.
    /// </summary>
    local procedure CalcProfit(SalesHeader: Record "Sales Header"): Decimal
    var
        SalesLine: Record "Sales Line";
        CurrExchRate: Record "Currency Exchange Rate";
        TotalRevenue: Decimal;
        TotalCostLCY: Decimal;
        TotalCost: Decimal;
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetFilter(Type, '<>%1', SalesLine.Type::" ");
        if SalesLine.FindSet() then
            repeat
                TotalRevenue += SalesLine."Line Amount";
                TotalCostLCY += SalesLine."Unit Cost (LCY)" * SalesLine.Quantity;
            until SalesLine.Next() = 0;

        TotalCost := TotalCostLCY;
        if SalesHeader."Currency Code" <> '' then begin
            // Currency Factor may be 0 on a header that was never validated: fall back to the exchange rate table.
            if SalesHeader."Currency Factor" <> 0 then
                TotalCost := CurrExchRate.ExchangeAmtLCYToFCY(
                    SalesHeader."Posting Date", SalesHeader."Currency Code", TotalCostLCY, SalesHeader."Currency Factor")
            else
                TotalCost := CurrExchRate.ExchangeAmtLCYToFCY(
                    SalesHeader."Posting Date", SalesHeader."Currency Code", TotalCostLCY,
                    CurrExchRate.ExchangeRate(SalesHeader."Posting Date", SalesHeader."Currency Code"));
        end;

        exit(TotalRevenue - TotalCost);
    end;

    local procedure GetCurrencyCode(SalesHeader: Record "Sales Header"): Code[10]
    var
        GLSetup: Record "General Ledger Setup";
    begin
        if SalesHeader."Currency Code" <> '' then
            exit(SalesHeader."Currency Code");
        GLSetup.Get();
        exit(GLSetup."LCY Code");
    end;

    /// <summary>
    /// Direct web client link to the approval request entry, so the approver can approve straight away.
    /// </summary>
    local procedure GetApprovalLink(ApprovalEntry: Record "Approval Entry"): Text
    var
        ApprovalEntryFilter: Record "Approval Entry";
    begin
        ApprovalEntryFilter.SetRange("Entry No.", ApprovalEntry."Entry No.");
        exit(GetUrl(ClientType::Web, CompanyName(), ObjectType::Page, Page::"Approval Request Entries", ApprovalEntryFilter, true));
    end;

    var
        OverdueBalanceTxt: Label 'Overdue balance';
        ExposureExceedsTxt: Label 'Exposure exceeds credit limit';
        BalanceExceedsTxt: Label 'Balance exceeds credit limit';
        ManualRequestTxt: Label 'Manual approval request';
}
