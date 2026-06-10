page 80000 "INT Approval Requests API"
{
    PageType = API;
    SourceTable = "INT Approval Request";
    DelayedInsert = true;
    APIPublisher = 'Default';
    APIGroup = 'Approvals';
    APIVersion = 'v2.0';
    EntityName = 'approvalRequest';
    EntitySetName = 'approvalRequests';
    Caption = 'Integration Approval Requests API';

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field(id; Rec.SystemId) { Caption = 'id'; }
                field(entryNo; Rec."Entry No.") { Caption = 'entryNo'; }
                field(documentType; Rec."Document Type") { Caption = 'documentType'; }
                field(documentNo; Rec."Document No.") { Caption = 'documentNo'; }
                field(status; Rec.Status) { Caption = 'status'; }
                field(createdAt; Rec."Created At") { Caption = 'createdAt'; }
                field(processedAt; Rec."Processed At") { Caption = 'processedAt'; }
                field(lastError; Rec."Last Error") { Caption = 'lastError'; }
                field(salesDocumentSystemId; Rec."Sales Document SystemId") { Caption = 'salesDocumentSystemId'; }
            }
        }
    }

    // trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    // var
    //     Processor: Codeunit "INT Approval Request Processor";
    // begin
    //     Processor.TryProcessEntry(Rec);
    //     exit(false);
    // end;
}