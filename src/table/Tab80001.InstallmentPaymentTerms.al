table 80001 "Installment Payment Terms"
{
    Caption = 'Installment Payment Terms';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
        }
        field(2; "Description"; Text[100])
        {
            Caption = 'Description';
        }
        field(3; "No. of Installments"; Integer)
        {
            Caption = 'No. of Installments';
            MinValue = 2;
        }
        field(4; "Days Between Installments"; Integer)
        {
            Caption = 'Days Between Installments';
            MinValue = 1;
        }
    }

    keys
    {
        key(PK; "Code") { Clustered = true; }
    }
}

