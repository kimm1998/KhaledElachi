codeunit 80011 WorkflowApprovalMgt
{
    Permissions = TableData "Approval Entry" = RMID;

    trigger OnRun()
    begin

    end;

    procedure CloseSequenceApprovalsResponseCode(): Code[128]
    begin
        exit('CLOSESEQUENCEAPPROVALS');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Workflow Response Handling", 'OnAddWorkflowResponsesToLibrary', '', false, false)]
    local procedure OnAddWorkflowResponsesToLibrary()
    begin
        WorkflowResponseHandling.AddResponseToLibrary(
            CloseSequenceApprovalsResponseCode(),
            Database::"Approval Entry",
            'Close all other open approval entries at the same sequence (first-one-wins).',
            'GROUP 0');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Workflow Response Handling", 'OnExecuteWorkflowResponse', '', false, false)]
    local procedure OnExecuteWorkflowResponse(var ResponseExecuted: Boolean; Variant: Variant; xVariant: Variant; ResponseWorkflowStepInstance: Record "Workflow Step Instance")
    begin
        case ResponseWorkflowStepInstance."Function Name" of
            CloseSequenceApprovalsResponseCode():
                begin
                    CloseSequenceApprovalsResponse(Variant);
                    ResponseExecuted := true;
                end;
        end;
    end;
    local procedure CloseSequenceApprovalsResponse(Variant: Variant)
    var
        ApprovedEntry: Record "Approval Entry";
        SiblingEntry: Record "Approval Entry";
    begin
        ApprovedEntry := Variant;

        SiblingEntry.SetRange("Table ID", ApprovedEntry."Table ID");
        SiblingEntry.SetRange("Document No.", ApprovedEntry."Document No.");
        SiblingEntry.SetRange("Sequence No.", ApprovedEntry."Sequence No.");
        SiblingEntry.SetRange(Status, SiblingEntry.Status::Open);
        SiblingEntry.SetFilter("Entry No.", '<>%1', ApprovedEntry."Entry No.");
        SiblingEntry.SetRange("Workflow Step Instance ID", ApprovedEntry."Workflow Step Instance ID");

        if SiblingEntry.FindSet(true) then
            repeat
                SiblingEntry.Status := SiblingEntry.Status::Approved;
                SiblingEntry.Modify(true);
            until SiblingEntry.Next() = 0;
    end;

    var
        WorkflowResponseHandling: Codeunit "Workflow Response Handling";
        workflowsetup: Codeunit "Workflow Setup";
        approvalEntry: Record "Approval Entry";
}