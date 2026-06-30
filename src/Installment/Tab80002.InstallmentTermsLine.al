table 80002 "Installment Terms Line"
{
    Caption = 'Installment Terms Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            TableRelation = "Installment Payment Terms".Code;
            NotBlank = true;
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(3; "Installment No."; Integer)
        {
            Caption = 'Installment No.';
            Editable = false;
        }
        field(4; "Percentage"; Decimal)
        {
            Caption = 'Percentage (%)';
            MinValue = 0.01;
            MaxValue = 100;
            DecimalPlaces = 2 : 2;

            trigger OnValidate()
            var
                SiblingTotal: Decimal;
            begin
                SiblingTotal := GetSiblingTotal();
                if SiblingTotal + Rec.Percentage > 100 then
                    Error('Total percentage would be %1%%. Maximum is 100%%. Remaining available: %2%%.',
                        SiblingTotal + Rec.Percentage,
                        100 - SiblingTotal);
            end;
        }
        field(5; "Days from Posting Date"; Integer)
        {
            Caption = 'Days from Posting Date';
            MinValue = 1;
            ToolTip = 'Number of days after posting date when this installment is due. E.g. 30, 60, 90.';
        }
    }

    keys
    {
        key(PK; "Code", "Line No.") { Clustered = true; }
        key(SortKey; "Code", "Installment No.") { }
    }

    local procedure GetSiblingTotal(): Decimal
    var
        Sibling: Record "Installment Terms Line";
        Total: Decimal;
    begin
        Sibling.SetRange("Code", Rec."Code");
        Sibling.SetFilter("Line No.", '<>%1', Rec."Line No.");
        if Sibling.FindSet() then
            repeat
                Total += Sibling.Percentage;
            until Sibling.Next() = 0;
        exit(Total);
    end;

    procedure GetTotalPercentage(): Decimal
    var
        Line: Record "Installment Terms Line";
        Total: Decimal;
    begin
        Line.SetRange("Code", Rec."Code");
        if Line.FindSet() then
            repeat
                Total += Line.Percentage;
            until Line.Next() = 0;
        exit(Total);
    end;
}