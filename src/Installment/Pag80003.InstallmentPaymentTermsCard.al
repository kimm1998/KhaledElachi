page 80003 "Installment Payment Terms Card"
{
    Caption = 'Installment Payment Terms';
    PageType = Card;
    SourceTable = "Installment Payment Terms";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Code"; Rec."Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Unique code for this installment term.';
                }
                field("Description"; Rec."Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Description of this installment term.';
                }
                field(TotalPctField; TotalPct)
                {
                    ApplicationArea = All;
                    Caption = 'Total Percentage';
                    Editable = false;
                    StyleExpr = TotalPctStyle;
                    ToolTip = 'Sum of all installment percentages. Must equal 100% before using this term.';
                }
            }
            part(Lines; "Installment Terms Subpage")
            {
                ApplicationArea = All;
                SubPageLink = "Code" = field("Code");
                Caption = 'Installment Lines';
                UpdatePropagation = Both;
            }
        }
    }

    var
        TotalPct: Decimal;
        TotalPctStyle: Text;

    trigger OnAfterGetRecord()
    begin
        RefreshTotalPct();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        RefreshTotalPct();
    end;

    local procedure RefreshTotalPct()
    var
        Line: Record "Installment Terms Line";
    begin
        TotalPct := 0;
        Line.SetRange("Code", Rec."Code");
        if Line.FindSet() then
            repeat
                TotalPct += Line.Percentage;
            until Line.Next() = 0;

        if TotalPct = 100 then
            TotalPctStyle := 'Favorable'
        else
            TotalPctStyle := 'Attention';
    end;
}