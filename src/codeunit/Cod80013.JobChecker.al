codeunit 80013 "ResetJobQueueEntry"
{
    Access = Public;

    trigger OnRun()
    begin
        ResetSpecificJobQueueEntry();
    end;

    local procedure ResetSpecificJobQueueEntry()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", 80007);
        JobQueueEntry.SetRange(Status, JobQueueEntry.Status::Error);
        if JobQueueEntry.FindFirst() then begin
            JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);
        end;
    end;
}