pageextension 80012 "Appr. Req. Entries Webhook" extends "Approval Request Entries"
{
    actions
    {
        addlast(processing)
        {
            action(SendToApprovalWebhook)
            {
                ApplicationArea = All;
                Caption = 'Send to Approval Webhook';
                Image = SendTo;
                ToolTip = 'Sends this sales order approval request to the approval webhook again. Use it to ping the API for an existing request.';

                trigger OnAction()
                var
                    OrderApprWebhook: Codeunit "Order Appr. Request Webhook";
                begin
                    OrderApprWebhook.ResendForApprovalEntry(Rec);
                end;
            }
            action(ViewApprovalWebhookLog)
            {
                ApplicationArea = All;
                Caption = 'Approval Webhook Log';
                Image = Log;
                RunObject = page "Approval Webhook Log";
                ToolTip = 'Shows successful and failed approval webhook requests.';
            }
        }
    }
}
