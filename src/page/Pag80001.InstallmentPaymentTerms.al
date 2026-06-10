page 80001 "Installment Payment Terms"
{
    Caption = 'Installment Payment Terms';
    PageType = List;
    SourceTable = "Installment Payment Terms";
    UsageCategory = Administration;
    ApplicationArea = All;
    CardPageId = "Installment Payment Terms Card"; // <-- ADD THIS LINE

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Code"; Rec."Code") { ApplicationArea = All; }
                field("Description"; Rec."Description") { ApplicationArea = All; }
            }
        }
    }
}