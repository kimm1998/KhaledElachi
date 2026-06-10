codeunit 80009 "Job Queue Error Notifier"
{

    trigger OnRun()
    begin
        CheckJobQueueErrors();
    end;

    local procedure CheckJobQueueErrors()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", 80007);
        JobQueueEntry.SetRange(Status, JobQueueEntry.Status::Error);

        if not JobQueueEntry.FindSet() then
            exit;

        repeat
            SendErrorNotificationEmail(JobQueueEntry);
        until JobQueueEntry.Next() = 0;
    end;

    local procedure SendErrorNotificationEmail(JobQueueEntry: Record "Job Queue Entry")
    var
        EmailMessage: Codeunit "Email Message";
        Email: Codeunit Email;
        Recipients: List of [Text];
        Subject: Text;
        Body: Text;
    begin
        Subject := StrSubstNo('⚠️ Job Queue Error – Codeunit %1: %2',
            JobQueueEntry."Object ID to Run",
            JobQueueEntry.Description);

        Body := BuildEmailBody(JobQueueEntry);

        Recipients.Add(GetRecipientEmail());

        EmailMessage.Create(Recipients, Subject, Body, true);

        if not Email.Send(EmailMessage, Enum::"Email Scenario"::Default) then
            Error('Failed to send Job Queue error notification email for entry: %1', JobQueueEntry.ID);
    end;

    local procedure BuildEmailBody(JobQueueEntry: Record "Job Queue Entry"): Text
    var
        BodyBuilder: TextBuilder;
    begin
        BodyBuilder.AppendLine('<!DOCTYPE html><html><body>');
        BodyBuilder.AppendLine('<h2 style="color:#c0392b;">Job Queue Entry Error Detected</h2>');
        BodyBuilder.AppendLine('<p>The following Job Queue entry has encountered an error:</p>');
        BodyBuilder.AppendLine('<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;font-family:Arial,sans-serif;">');

        AppendTableRow(BodyBuilder, 'Entry ID', Format(JobQueueEntry.ID));
        AppendTableRow(BodyBuilder, 'Description', JobQueueEntry.Description);
        AppendTableRow(BodyBuilder, 'Object Type', Format(JobQueueEntry."Object Type to Run"));
        AppendTableRow(BodyBuilder, 'Object ID', Format(JobQueueEntry."Object ID to Run"));
        AppendTableRow(BodyBuilder, 'Status', Format(JobQueueEntry.Status));
        AppendTableRow(BodyBuilder, 'Error Message', JobQueueEntry."Error Message");
        AppendTableRow(BodyBuilder, 'Earliest Start Date/Time', Format(JobQueueEntry."Earliest Start Date/Time"));
        AppendTableRow(BodyBuilder, 'Last Ready State', Format(JobQueueEntry."Last Ready State"));

        BodyBuilder.AppendLine('</table>');
        BodyBuilder.AppendLine('<br/><p style="color:#7f8c8d;font-size:12px;">This is an automated message from Business Central.</p>');
        BodyBuilder.AppendLine('</body></html>');

        exit(BodyBuilder.ToText());
    end;

    local procedure AppendTableRow(var BodyBuilder: TextBuilder; Label: Text; Value: Text)
    begin
        BodyBuilder.AppendLine(
            StrSubstNo('<tr><td style="font-weight:bold;background:#f2f2f2;width:200px;">%1</td><td>%2</td></tr>',
                Label, Value));
    end;

    local procedure GetRecipientEmail(): Text
    begin
        exit('Riad.rifai@greenbridge.co');
    end;
}