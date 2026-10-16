page 80010 "Approval Webhook Log"
{
    Caption = 'Approval Webhook Log';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Approval Webhook Log";
    SourceTableView = sorting("Entry No.") order(descending);
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                }
                field("Created At"; Rec."Created At")
                {
                    ApplicationArea = All;
                }
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                }
                field("Trigger Type"; Rec."Trigger Type")
                {
                    ApplicationArea = All;
                }
                field("Order No."; Rec."Order No.")
                {
                    ApplicationArea = All;
                }
                field("Approval Entry No."; Rec."Approval Entry No.")
                {
                    ApplicationArea = All;
                }
                field(Success; Rec.Success)
                {
                    ApplicationArea = All;
                    StyleExpr = StyleTxt;
                }
                field("HTTP Status Code"; Rec."HTTP Status Code")
                {
                    ApplicationArea = All;
                }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ShowRequest)
            {
                ApplicationArea = All;
                Caption = 'Show Request';
                Image = ViewDetails;
                ToolTip = 'Shows the JSON body that was sent (the auth token is masked).';

                trigger OnAction()
                begin
                    Message(CopyStr(Rec.GetRequestBody(), 1, 1000));
                end;
            }
            action(ShowResponse)
            {
                ApplicationArea = All;
                Caption = 'Show Response';
                Image = ViewDetails;
                ToolTip = 'Shows the first part of the response returned by the endpoint.';

                trigger OnAction()
                begin
                    Message(CopyStr(Rec.GetResponseBody(), 1, 1000));
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        if Rec.Success then
            StyleTxt := 'Favorable'
        else
            StyleTxt := 'Unfavorable';
    end;

    var
        StyleTxt: Text;
}
