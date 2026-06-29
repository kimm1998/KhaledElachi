table 80000 "INT Approval Request"
{
    Caption = 'Integration Approval Request';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }

        field(2; "Document Type"; Text[30])
        {
            Caption = 'Document Type';
            DataClassification = CustomerContent;
        }

        field(3; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            DataClassification = CustomerContent;
        }

        field(10; Status; Enum "INT Approval Req Status")
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
        }

        field(11; "Created At"; DateTime)
        {
            Caption = 'Created At';
            DataClassification = SystemMetadata;
        }

        field(12; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
            DataClassification = SystemMetadata;
        }

        field(13; "Last Error"; Text[2048])
        {
            Caption = 'Last Error';
            DataClassification = CustomerContent;
        }

        field(14; "Sales Document SystemId"; Guid)
        {
            Caption = 'Sales Document SystemId';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }

        // Idempotency key: prevents duplicate requests for same document.
        // key(DocKey; "Document Type", "Document No.")
        // {
        //     Unique = true;
        // }
    }

    trigger OnInsert()
    begin
        if "Created At" = 0DT then
            "Created At" := CurrentDateTime();

        if Status = Status::" " then
            Status := Status::New;
    end;
}