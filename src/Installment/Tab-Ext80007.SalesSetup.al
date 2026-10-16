tableextension 80007 SalesSetupExt extends "Sales & Receivables Setup"
{
    fields
    {
        // Add changes to table fields here
        Field(80000; "Installement Bal. Acc."; Code[20])
        {
            Caption = 'Installment Balancing Account';
            DataClassification = ToBeClassified;
            tableRelation = "G/L Account"."No.";
        }
        field(80001; "Installment Batch Name"; Code[20])
        {
            Caption = 'Installment Batch Name';
            DataClassification = ToBeClassified;
            tableRelation = "Gen. Journal Batch".Name where("Journal Template Name" = const('GENERAL'));
        }
        field(80002; "Installment Bal. Acc. VAT"; Code[20])
        {
            Caption = 'Installment Balancing Account VAT';
            tableRelation = "G/L Account"."No.";
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