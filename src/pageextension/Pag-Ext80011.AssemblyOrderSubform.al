pageextension 80011 AssemblyOrderSubformExt extends "Assembly Order Subform"
{
    layout
    {
        addbefore("Quantity to Consume")
        {
            field("GBC Qty To Consume"; Rec."GBC Qty To Consume")
            {
                ApplicationArea = All;
                Caption = 'Quantity To Consume';
                ToolTip = 'Specifies the quantity to consume.';
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
}