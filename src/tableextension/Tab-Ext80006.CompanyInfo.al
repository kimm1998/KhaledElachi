tableextension 80006 CompInfo extends "Company Information"
{
    fields
    {
        field(80000; "API Country"; Text[50])
        {
            Caption = 'API Country';
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        // Add changes to keys here
    }

    fieldgroups
    {
        // Add changes to field groups here
    }

    var
        myInt: Integer;
}