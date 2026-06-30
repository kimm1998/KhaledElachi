tableextension 80002 "Payment Terms Ext" extends "Payment Terms"
{
    fields
    {
        field(50100; "Installment Code"; Code[20])//installemnt
        {
            Caption = 'Installment Code';
            TableRelation = "Installment Payment Terms".Code;
            DataClassification = CustomerContent;
        }
    }
}

