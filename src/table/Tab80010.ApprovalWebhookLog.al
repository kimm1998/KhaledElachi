table 80010 "Approval Webhook Log"
{
    Caption = 'Approval Webhook Log';
    DataClassification = CustomerContent;
    LookupPageId = "Approval Webhook Log";
    DrillDownPageId = "Approval Webhook Log";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Created At"; DateTime)
        {
            Caption = 'Created At';
        }
        field(3; "User ID"; Code[50])
        {
            Caption = 'User ID';
        }
        field(4; "Trigger Type"; Enum "Approval Webhook Trigger")
        {
            Caption = 'Trigger Type';
        }
        field(5; "Order No."; Code[20])
        {
            Caption = 'Order No.';
        }
        field(6; "Approval Entry No."; Integer)
        {
            Caption = 'Approval Entry No.';
        }
        field(7; Success; Boolean)
        {
            Caption = 'Success';
        }
        field(8; "HTTP Status Code"; Integer)
        {
            Caption = 'HTTP Status Code';
        }
        field(9; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
        }
        field(10; "Request Body"; Blob)
        {
            Caption = 'Request Body';
        }
        field(11; "Response Body"; Blob)
        {
            Caption = 'Response Body';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(CreatedAt; "Created At")
        {
        }
    }

    procedure SetRequestBody(Body: Text)
    var
        OutStr: OutStream;
    begin
        Clear("Request Body");
        "Request Body".CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(Body);
    end;

    procedure SetResponseBody(Body: Text)
    var
        OutStr: OutStream;
    begin
        Clear("Response Body");
        "Response Body".CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(Body);
    end;

    procedure GetRequestBody(): Text
    var
        InStr: InStream;
    begin
        CalcFields("Request Body");
        if not "Request Body".HasValue() then
            exit('');
        "Request Body".CreateInStream(InStr, TextEncoding::UTF8);
        exit(ReadStream(InStr));
    end;

    procedure GetResponseBody(): Text
    var
        InStr: InStream;
    begin
        CalcFields("Response Body");
        if not "Response Body".HasValue() then
            exit('');
        "Response Body".CreateInStream(InStr, TextEncoding::UTF8);
        exit(ReadStream(InStr));
    end;

    local procedure ReadStream(var InStr: InStream): Text
    var
        Line: Text;
        Result: Text;
        NewLine: Text[2];
    begin
        NewLine[1] := 13;
        NewLine[2] := 10;
        while not InStr.EOS() do begin
            InStr.ReadText(Line);
            if Result <> '' then
                Result += NewLine;
            Result += Line;
        end;
        exit(Result);
    end;
}
