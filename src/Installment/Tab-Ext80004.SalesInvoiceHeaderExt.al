tableextension 80004 "Sales Invoice Header Ext" extends "Sales Invoice Header"
{
    fields
    {
        field(80010; "Installment Code"; Code[20])//installemnt
        {
            Caption = 'Installment Code';
            DataClassification = CustomerContent;
        }
        field(80011; "Installments Applied"; Boolean)//installemnt
        {
            Caption = 'Installments Applied';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(80012; "Installment Code Applied"; Code[20])//installemnt
        {
            Caption = 'Installment Code Applied';
            DataClassification = CustomerContent;
            TableRelation = "Installment Payment Terms".Code;
            Editable = false;
        }
    }
}