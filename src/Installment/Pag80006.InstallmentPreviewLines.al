page 80006 "Installment Preview Lines"
{
    Caption = 'Split Preview';
    PageType = ListPart;
    SourceTable = "Installment Preview Line";
    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Installment No."; Rec."Installment No.") { ApplicationArea = All; Caption = '#'; }
                field("Percentage"; Rec.Percentage) { ApplicationArea = All; Caption = 'Percentage (%)'; }
                field("Amount"; Rec.Amount) { ApplicationArea = All; Caption = 'Amount'; }
                field("Due Date"; Rec."Due Date") { ApplicationArea = All; Caption = 'Due Date'; }
                field("Description"; Rec.Description) { ApplicationArea = All; Caption = 'Description'; }
            }
        }
    }

    procedure LoadLines(var TempLines: Record "Installment Preview Line" temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();
        if TempLines.FindSet() then
            repeat
                Rec := TempLines;
                Rec.Insert();
            until TempLines.Next() = 0;
        CurrPage.Update(false);
    end;
}