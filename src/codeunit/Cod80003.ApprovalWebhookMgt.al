codeunit 80003 "Approval Webhook Mgt."
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Approvals Mgmt.", 'OnApproveApprovalRequest', '', false, false)]
    local procedure OnAfterApproveApprovalRequest(var ApprovalEntry: Record "Approval Entry")
    begin
        SendApprovalWebhook(ApprovalEntry);
    end;

    // local procedure SendApprovalWebhook(var ApprovalEntry: Record "Approval Entry")
    // var
    //     Client: HttpClient;
    //     Content: HttpContent;
    //     Headers: HttpHeaders;
    //     Response: HttpResponseMessage;
    //     JObject: JsonObject;
    //     ResponseText: Text;
    //     Url: Text;
    // begin
    //     Url := 'https://script.google.com/macros/s/AKfycbyooTRNZL1GdtJyds6JaryXkY8Hf_ZWZprWEHLiZUj3aTFwU-AGbmeFAYtvSYIPJ1Uu/exec';

    //     JObject.Add('authToken', '8f3c1a9d-6b72-4c5e-91a0-3d7f2c9e5b44');
    //     JObject.Add('orderNo', ApprovalEntry."Document No.");
    //     JObject.Add('approver', ApprovalEntry."Approver ID");

    //     Content.WriteFrom(Format(JObject));

    //     Content.GetHeaders(Headers);
    //     if Headers.Contains('Content-Type') then
    //         Headers.Remove('Content-Type');
    //     Headers.Add('Content-Type', 'application/json');

    //     if not Client.Post(Url, Content, Response) then
    //         Error('Failed to send approval webhook.');

    //     if not Response.IsSuccessStatusCode() then begin
    //         Response.Content().ReadAs(ResponseText);
    //         Error(
    //           'Approval webhook failed. Status code: %1. Response: %2',
    //           Response.HttpStatusCode(),
    //           ResponseText);
    //     end;
    // end;
    local procedure SendApprovalWebhook(var ApprovalEntry: Record "Approval Entry")
    var
        HttpClient: HttpClient;
        HttpRequestMessage: HttpRequestMessage;
        HttpResponseMessage: HttpResponseMessage;
        HttpContent: HttpContent;
        HttpHeaders: HttpHeaders;
        RequestBody: Text;
        ResponseText: Text;
        WebhookUrl: Text;
    begin

        // Build webhook URL
        WebhookUrl := 'https://script.google.com/macros/s/AKfycbyooTRNZL1GdtJyds6JaryXkY8Hf_ZWZprWEHLiZUj3aTFwU-AGbmeFAYtvSYIPJ1Uu/exec';

        // Build JSON body
        RequestBody := BuildJson(ApprovalEntry);

        // Setup HTTP request
        HttpContent.WriteFrom(RequestBody);
        HttpContent.GetHeaders(HttpHeaders);
        HttpHeaders.Clear();
        HttpHeaders.Add('Content-Type', 'application/json');

        HttpRequestMessage.Method := 'POST';
        HttpRequestMessage.SetRequestUri(WebhookUrl);
        HttpRequestMessage.Content := HttpContent;


        // Send request
        if not HttpClient.Send(HttpRequestMessage, HttpResponseMessage) then begin
        end;

        // Check response
        HttpResponseMessage.Content.ReadAs(ResponseText);

        if HttpResponseMessage.IsSuccessStatusCode() then begin

        end;
    end;

    local procedure BuildJson(ApprovalEntry: Record "Approval Entry"): Text
    var
        JObject: JsonObject;
        JsonText: Text;
        CompInfo: record "Company Information";
    begin
        compInfo.Get();
        JObject.Add('authToken', '8f3c1a9d-6b72-4c5e-91a0-3d7f2c9e5b44');
        JObject.Add('orderNo', ApprovalEntry."Document No.");
        JObject.Add('approver', ApprovalEntry."Approver ID");
        JObject.Add('performedBy', GetPerformedByUserId(ApprovalEntry."Document No."));
        JObject.Add('entity', compinfo."API Country");

        JObject.WriteTo(JsonText);
        exit(JsonText);
    end;

    local Procedure GetPerformedByUserId(DocumentNo: Code[20]): Text
    var
        INTApproval: Record "INT Approval Request";
    begin
        intApproval.SetRange("Document No.", DocumentNo);
        if intApproval.FindLast() then
            exit(intApproval."Performed By ID");
        exit('');

    end;
}