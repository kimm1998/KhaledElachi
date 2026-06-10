page 80002 "Installment Terms Subpage"
{
    Caption = 'Installment Schedule';
    PageType = ListPart;
    SourceTable = "Installment Terms Line";
    AutoSplitKey = true;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Installment No."; Rec."Installment No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Sequence number of this installment.';
                }
                field("Percentage"; Rec."Percentage")
                {
                    ApplicationArea = All;
                    ToolTip = 'Percentage of the total invoice amount for this installment. All lines must total 100%.';
                }
                field("Days from Posting Date"; Rec."Days from Posting Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Days after posting date when this payment is due. E.g. 30 = one month.';
                }
            }
        }
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        Rec."Installment No." := GetNextInstallmentNo();
    end;

    local procedure GetNextInstallmentNo(): Integer
    var
        Line: Record "Installment Terms Line";
    begin
        Line.SetRange("Code", Rec."Code");
        if Line.FindLast() then
            exit(Line."Installment No." + 1);
        exit(1);
    end;
}