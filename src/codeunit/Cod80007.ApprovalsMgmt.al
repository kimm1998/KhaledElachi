codeunit 80007 "Approvals Mgmt"
{
    trigger OnRun()
    var
        apprvalRequests: Record "INT Approval Request";
        Processor: Codeunit "INT Approval Request Processor";
    begin
        apprvalRequests.SetRange(Status, apprvalRequests.Status::New);
        if apprvalRequests.FindSet() then
            repeat
                Processor.TryProcessEntry(apprvalRequests);
            until apprvalRequests.Next() = 0;

    end;

    var
        myInt: Integer;
}