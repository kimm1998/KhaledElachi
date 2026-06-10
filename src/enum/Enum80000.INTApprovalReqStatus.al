enum 80000 "INT Approval Req Status"
{
    Extensible = true;
    Caption = 'Integration Approval Request Status';
    value(0; " ") { Caption = ''; }
    value(1; New) { Caption = 'New'; }
    value(2; Processed) { Caption = 'Processed'; }
    value(3; Error) { Caption = 'Error'; }
}