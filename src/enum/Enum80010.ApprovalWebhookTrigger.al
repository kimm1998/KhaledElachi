enum 80010 "Approval Webhook Trigger"
{
    Extensible = true;

    value(0; Automatic)
    {
        Caption = 'Automatic';
    }
    value(1; "Manual Resend")
    {
        Caption = 'Manual Resend';
    }
    value(2; "Manual Test")
    {
        Caption = 'Manual Test';
    }
}
