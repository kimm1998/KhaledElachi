page 80005 "Installment Schedule FactBox"
{
    Caption = 'Installment Schedule';
    PageType = ListPart;
    SourceTable = "Cust. Ledger Entry";
    Editable = false;
    RefreshOnActivate = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Document No."; Rec."Document No.") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Due Date"; Rec."Due Date") { ApplicationArea = All; }
                field(Amount; Rec."Remaining Amount")
                {
                    ApplicationArea = All;
                    Caption = 'Remaining Amount';
                }
                field(Open; Rec.Open) { ApplicationArea = All; }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Remaining Amount");
    end;

    procedure SetInvoiceFilter(InvoiceNo: Code[20]; CustNo: Code[20])
    begin
        Rec.SetRange("Customer No.", CustNo);
        Rec.SetFilter("Document No.", InvoiceNo + '|' + InvoiceNo + '-I*');
        Rec.SetRange("Document Type", Rec."Document Type"::Invoice);
        CurrPage.Update(false);
    end;
}