codeunit 80002 "Sales Exposure Wkfl. Handler"
{
    // ── Unique code that identifies our custom workflow event ──────────────
    procedure RunWorkflowOnExposureOverLimitCode(): Code[128]
    begin
        exit('RUNSALESEXPOSUREOVERCREDITLIMIT');
    end;

    // ── Register the event so it appears in the Workflow Events library ────
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Workflow Event Handling", 'OnAddWorkflowEventsToLibrary', '', false, false)]
    local procedure AddWorkflowEventsToLibrary()
    var
        WorkflowEventHandling: Codeunit "Workflow Event Handling";
    begin
        WorkflowEventHandling.AddEventToLibrary(
            RunWorkflowOnExposureOverLimitCode(),
            Database::"Sales Header",
            SalesExposureOverLimitDescTxt,
            0,       // no filter request page
            false);  // no usage restrictions
    end;

    // ── Link Sales Header → Approval Entry so the workflow engine can track
    //    approvals against this document ────────────────────────────────────
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Workflow Event Handling", 'OnAddWorkflowTableRelationsToLibrary', '', false, false)]
    local procedure AddWorkflowTableRelationsToLibrary()
    var
        WorkflowEventHandling: Codeunit "Workflow Event Handling";
        SalesHeader: Record "Sales Header";
        ApprovalEntry: Record "Approval Entry";
    begin
        // WorkflowEventHandling.AddTableRelationToLibrary(
        //     RunWorkflowOnExposureOverLimitCode(),
        //     Database::"Sales Header",
        //     Database::"Approval Entry",
        //     SalesHeader.FieldNo("Document Type"),
        //     ApprovalEntry.FieldNo("Document Type"));
        WorkflowEventHandling.AddEventToLibrary(
            RunWorkflowOnExposureOverLimitCode(),
            Database::"Sales Header",
            SalesApprovalRequestedTxt,0, false);
    end;

    // ── Allow standard approval responses (Create / Send / Set Status) to be
    //    used as successors to our custom event in the workflow designer ────
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Workflow Response Handling", 'OnAddWorkflowResponsePredecessorsToLibrary', '', false, false)]
    local procedure AddWorkflowResponsePredecessors(ResponseFunctionName: Code[128])
    var
        WorkflowEventHandling: Codeunit "Workflow Event Handling";
        WorkflowResponseHandling: Codeunit "Workflow Response Handling";
    begin
        case ResponseFunctionName of
            WorkflowResponseHandling.CreateApprovalRequestsCode():
                WorkflowEventHandling.AddEventPredecessor(
                    ResponseFunctionName, RunWorkflowOnExposureOverLimitCode());
            WorkflowResponseHandling.SendApprovalRequestForApprovalCode():
                WorkflowEventHandling.AddEventPredecessor(
                    ResponseFunctionName, RunWorkflowOnExposureOverLimitCode());
            WorkflowResponseHandling.SetStatusToPendingApprovalCode():
                WorkflowEventHandling.AddEventPredecessor(
                    ResponseFunctionName, RunWorkflowOnExposureOverLimitCode());
            WorkflowResponseHandling.OpenDocumentCode():
                WorkflowEventHandling.AddEventPredecessor(
                    ResponseFunctionName, RunWorkflowOnExposureOverLimitCode());
        end;
    end;

    var
        SalesExposureOverLimitDescTxt: Label 'Sales document exposure exceeds credit limit';
        SalesApprovalRequestedTxt: Label ' Sales Approval Requested';
}