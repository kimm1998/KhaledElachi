table 80003 "Installment Application Log"
{
    Caption = 'Installment Application Log';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Document No."; Code[20]) { Caption = 'Document No.'; }
        field(3; "Customer No."; Code[20]) { Caption = 'Customer No.'; }
        field(4; "Applied Date"; Date) { Caption = 'Applied Date'; }
        field(5; "Applied Time"; Time) { Caption = 'Applied Time'; }
        field(6; "Applied By"; Code[50])
        {
            Caption = 'Applied By';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(7; "Installment Code"; Code[20]) { Caption = 'Installment Code'; }
        field(8; "Remaining Amount"; Decimal) { Caption = 'Remaining Amount at Split'; }
        field(9; "No. of Installments"; Integer) { Caption = 'No. of Installments'; }
        field(10; "Action Type"; Option)
        {
            Caption = 'Action';
            OptionMembers = Applied,Reset;
            OptionCaption = 'Applied,Reset';
        }
        field(11; "Currency Code"; Code[10]) { Caption = 'Currency Code'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(DocKey; "Document No.", "Applied Date") { }
    }
}