table 80004 "Installment Preview Line"
{
    Caption = 'Installment Preview Line';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "Line No."; Integer) { Caption = 'Line No.'; }
        field(2; "Installment No."; Integer) { Caption = '#'; }
        field(3; "Percentage"; Decimal) { Caption = 'Percentage (%)'; DecimalPlaces = 2 : 2; }
        field(4; "Amount"; Decimal) { Caption = 'Amount'; }
        field(5; "Due Date"; Date) { Caption = 'Due Date'; }
        field(6; "Description"; Text[100]) { Caption = 'Description'; }
    }

    keys
    {
        key(PK; "Line No.") { Clustered = true; }
    }
}