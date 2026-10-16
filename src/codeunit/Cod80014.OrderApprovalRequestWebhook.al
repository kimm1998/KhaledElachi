codeunit 80014 "Order Appr. Request Webhook"
{
    // Posts sales order approval requests to the Google Apps Script endpoint.
    // Every attempt is written to "Approval Webhook Log".
    // Failures are silent for the automatic trigger (they never block the approval request).

    Permissions = tabledata "Approval Webhook Log" = RIMD;

    [EventSubscriber(ObjectType::Table, Database::"Approval Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertApprovalEntry(var Rec: Record "Approval Entry"; RunTrigger: Boolean)
    var
        SalesHeader: Record "Sales Header";
        LogEntryNo: Integer;
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

        LogEntryNo := Dispatch(SalesHeader, Rec, Enum::"Approval Webhook Trigger"::Automatic);
    end;

    /// <summary>
    /// Sends an existing sales order approval entry to the webhook again (manual action).
    /// </summary>
    procedure ResendForApprovalEntry(ApprovalEntry: Record "Approval Entry")
    var
        SalesHeader: Record "Sales Header";
    begin
        if (ApprovalEntry."Table ID" <> Database::"Sales Header") or
           (ApprovalEntry."Document Type" <> ApprovalEntry."Document Type"::Order)
        then
            Error(NotSalesOrderErr);
        if not SalesHeader.Get(SalesHeader."Document Type"::Order, ApprovalEntry."Document No.") then
            Error(OrderNotFoundErr, ApprovalEntry."Document No.");
        if not Confirm(ConfirmResendQst, false, SalesHeader."No.") then
            exit;

        ShowResult(Dispatch(SalesHeader, ApprovalEntry, Enum::"Approval Webhook Trigger"::"Manual Resend"));
    end;

    /// <summary>
    /// Sends a sales order to the webhook without needing an approval request (manual test).
    /// </summary>
    procedure SendTestForOrder(SalesHeader: Record "Sales Header")
    var
        EmptyApprovalEntry: Record "Approval Entry";
    begin
        if SalesHeader."Document Type" <> SalesHeader."Document Type"::Order then
            Error(NotSalesOrderErr);
        if not Confirm(ConfirmTestQst, false, SalesHeader."No.") then
            exit;

        ShowResult(Dispatch(SalesHeader, EmptyApprovalEntry, Enum::"Approval Webhook Trigger"::"Manual Test"));
    end;

    /// <summary>
    /// Builds and sends the request, writes the log entry and returns its entry no. (0 if the log could not be written).
    /// </summary>
    local procedure Dispatch(SalesHeader: Record "Sales Header"; ApprovalEntry: Record "Approval Entry"; TriggerType: Enum "Approval Webhook Trigger"): Integer
    var
        LogBody: Text;
        ResponseText: Text;
        ErrorText: Text;
        StatusCode: Integer;
        Success: Boolean;
    begin
        ClearLastError();
        if TryBuildAndSend(SalesHeader, ApprovalEntry, LogBody, StatusCode, ResponseText) then begin
            Success := (StatusCode >= 200) and (StatusCode < 300);
            if not Success then
                ErrorText := StrSubstNo(HttpErrorTxt, StatusCode);
        end else
            ErrorText := GetLastErrorText();

        exit(WriteLog(SalesHeader, ApprovalEntry, TriggerType, Success, StatusCode, ErrorText, LogBody, ResponseText));
    end;

    [TryFunction]
    local procedure TryBuildAndSend(SalesHeader: Record "Sales Header"; ApprovalEntry: Record "Approval Entry"; var LogBody: Text; var StatusCode: Integer; var ResponseText: Text)
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        HttpContent: HttpContent;
        HttpHeaders: HttpHeaders;
        WebhookUrl: Text;
        RequestBody: Text;
    begin
        WebhookUrl := 'https://script.google.com/macros/s/AKfycbyooTRNZL1GdtJyds6JaryXkY8Hf_ZWZprWEHLiZUj3aTFwU-AGbmeFAYtvSYIPJ1Uu/exec';

        RequestBody := BuildJson(SalesHeader, ApprovalEntry, LogBody);

        HttpContent.WriteFrom(RequestBody);
        HttpContent.GetHeaders(HttpHeaders);
        HttpHeaders.Clear();
        HttpHeaders.Add('Content-Type', 'application/json');

        HttpRequestMessage.Method := 'POST';
        HttpRequestMessage.SetRequestUri(WebhookUrl);
        HttpRequestMessage.Content := HttpContent;

        if not HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then
            Error(ConnectionFailedErr);

        StatusCode := HttpResponseMessage.HttpStatusCode();
        HttpResponseMessage.Content().ReadAs(ResponseText);
    end;

    local procedure WriteLog(SalesHeader: Record "Sales Header"; ApprovalEntry: Record "Approval Entry"; TriggerType: Enum "Approval Webhook Trigger"; Success: Boolean; StatusCode: Integer; ErrorText: Text; LogBody: Text; ResponseText: Text): Integer
    var
        LogEntry: Record "Approval Webhook Log";
    begin
        LogEntry.Init();
        LogEntry."Created At" := CurrentDateTime();
        LogEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(LogEntry."User ID"));
        LogEntry."Trigger Type" := TriggerType;
        LogEntry."Order No." := SalesHeader."No.";
        LogEntry."Approval Entry No." := ApprovalEntry."Entry No.";
        LogEntry.Success := Success;
        LogEntry."HTTP Status Code" := StatusCode;
        LogEntry."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(LogEntry."Error Message"));
        LogEntry.SetRequestBody(LogBody);
        LogEntry.SetResponseBody(ResponseText);
        if LogEntry.Insert() then
            exit(LogEntry."Entry No.");
        exit(0);
    end;

    local procedure ShowResult(LogEntryNo: Integer)
    var
        LogEntry: Record "Approval Webhook Log";
    begin
        if (LogEntryNo = 0) or not LogEntry.Get(LogEntryNo) then begin
            Message(NoLogEntryMsg);
            exit;
        end;

        if LogEntry.Success then
            Message(SuccessMsg, LogEntry."HTTP Status Code", LogEntry."Entry No.")
        else
            Message(FailedMsg, LogEntry."Error Message", LogEntry."Entry No.");
    end;

    /// <summary>
    /// Builds the request body. LogBody receives the same JSON with the auth token masked, so it is safe to store.
    /// </summary>
    local procedure BuildJson(SalesHeader: Record "Sales Header"; ApprovalEntry: Record "Approval Entry"; var LogBody: Text): Text
    var
        Customer: Record Customer;
        CompanyInfo: Record "Company Information";
        CreditLimitMgmt: Codeunit "Sales Credit Limit Mgmt.";
        JObject: JsonObject;
        JLog: JsonObject;
        JData: JsonObject;
        JsonText: Text;
        CustomerNo: Code[20];
    begin
        CompanyInfo.Get();
        SalesHeader.CalcFields("Amount Including VAT");

        CustomerNo := SalesHeader."Bill-to Customer No.";
        if CustomerNo = '' then
            CustomerNo := SalesHeader."Sell-to Customer No.";

        JData.Add('orderLink', GetApprovalLink(SalesHeader, ApprovalEntry));
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

        // Same payload for the log, but with the token masked.
        JLog := JObject.Clone().AsObject();
        JLog.Replace('authToken', '***');
        JLog.WriteTo(LogBody);

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
    /// When there is no approval entry (manual test) it falls back to the sales order page.
    /// </summary>
    local procedure GetApprovalLink(SalesHeader: Record "Sales Header"; ApprovalEntry: Record "Approval Entry"): Text
    var
        ApprovalEntryFilter: Record "Approval Entry";
        SalesHeaderFilter: Record "Sales Header";
    begin
        if ApprovalEntry."Entry No." = 0 then begin
            SalesHeaderFilter.SetRange("Document Type", SalesHeader."Document Type");
            SalesHeaderFilter.SetRange("No.", SalesHeader."No.");
            exit(GetUrl(ClientType::Web, CompanyName(), ObjectType::Page, Page::"Sales Order", SalesHeaderFilter, true));
        end;

        ApprovalEntryFilter.SetRange("Entry No.", ApprovalEntry."Entry No.");
        exit(GetUrl(ClientType::Web, CompanyName(), ObjectType::Page, Page::"Approval Request Entries", ApprovalEntryFilter, true));
    end;

    var
        OverdueBalanceTxt: Label 'Overdue balance';
        ExposureExceedsTxt: Label 'Exposure exceeds credit limit';
        BalanceExceedsTxt: Label 'Balance exceeds credit limit';
        ManualRequestTxt: Label 'Manual approval request';
        ConnectionFailedErr: Label 'The request could not be sent (no response from the endpoint).';
        HttpErrorTxt: Label 'The endpoint returned HTTP status %1.', Comment = '%1 = HTTP status code';
        NotSalesOrderErr: Label 'This action only works for sales orders.';
        OrderNotFoundErr: Label 'Sales order %1 was not found.', Comment = '%1 = order no.';
        ConfirmResendQst: Label 'Send the approval request for sales order %1 to the webhook again?', Comment = '%1 = order no.';
        ConfirmTestQst: Label 'This sends sales order %1 to the live webhook as a test, without creating an approval request. Continue?', Comment = '%1 = order no.';
        SuccessMsg: Label 'Sent successfully (HTTP %1). Log entry %2.', Comment = '%1 = HTTP status code, %2 = log entry no.';
        FailedMsg: Label 'The request failed: %1 (log entry %2).', Comment = '%1 = error message, %2 = log entry no.';
        NoLogEntryMsg: Label 'The request was processed but the log entry could not be written.';
}
