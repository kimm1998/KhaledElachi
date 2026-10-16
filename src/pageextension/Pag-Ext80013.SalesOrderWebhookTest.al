pageextension 80013 "Sales Order Webhook Test" extends "Sales Order"
{
    actions
    {
        addlast(processing)
        {
            action(TestApprovalWebhook)
            {
                ApplicationArea = All;
                Caption = 'Test Approval Webhook';
                Image = TestFile;
                ToolTip = 'Sends this order to the approval webhook without creating an approval request.';

                trigger OnAction()
                var
                    OrderApprWebhook: Codeunit "Order Appr. Request Webhook";
                begin
                    OrderApprWebhook.SendTestForOrder(Rec);
                end;
            }
            action(ViewApprovalWebhookLogSO)
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
