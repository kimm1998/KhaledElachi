tableextension 80008 AsssmeblyLineExt extends "Assembly Line"
{
    fields
    {
        field(80000; "GBC Qty To Consume"; Decimal)
        {
            Caption = 'Quantity To Consume';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            trigger OnValidate()
            var
                myInt: Integer;
            begin
                rec.Validate("Quantity per",rec."GBC Qty To Consume"/Rec."Quantity");
                
            end;
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