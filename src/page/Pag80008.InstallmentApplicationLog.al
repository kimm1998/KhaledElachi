page 80008 "Installment Application Log"
{
    Caption = 'Installment Application Log';
    PageType = List;
    SourceTable = "Installment Application Log";
    Editable = false;
    UsageCategory = History;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Document No."; Rec."Document No.") { ApplicationArea = All; }
                field("Customer No."; Rec."Customer No.") { ApplicationArea = All; }
                field("Action Type"; Rec."Action Type") { ApplicationArea = All; }
                field("Installment Code"; Rec."Installment Code") { ApplicationArea = All; }
                field("No. of Installments"; Rec."No. of Installments") { ApplicationArea = All; }
                field("Remaining Amount"; Rec."Remaining Amount") { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
                field("Applied Date"; Rec."Applied Date") { ApplicationArea = All; }
                field("Applied Time"; Rec."Applied Time") { ApplicationArea = All; }
                field("Applied By"; Rec."Applied By") { ApplicationArea = All; }
            }
        }
    }
}