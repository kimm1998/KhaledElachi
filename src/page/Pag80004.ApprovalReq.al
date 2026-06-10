page 80004 ApprovalReq
{
    PageType = list;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "INT Approval Request";
    
    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    
                }
                field("Document Type"; Rec."Document Type")
                {
                    
                }
                field("Document No."; Rec."Document No.")
                {
                    
                }
                field(Status; Rec.Status)
                {
                    
                }
            }
        }
    }
    
    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                
                trigger OnAction()
                begin
                    
                end;
            }
        }
    }
    
    var
        myInt: Integer;
}