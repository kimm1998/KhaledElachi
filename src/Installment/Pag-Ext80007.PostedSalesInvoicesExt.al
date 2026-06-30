pageextension 80007 "Posted Sales Invoices Ext" extends "Posted Sales Invoices"
{
    layout
    {
        addafter("Payment Terms Code")
        {
            field("Installments Applied"; Rec."Installments Applied")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Indicates whether installment terms have been applied to this invoice.';
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            action(ApplyInstallmentTerms)
            {
                Caption = 'Apply Installment Terms';
                Image = PaymentTerms;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Split the selected invoice into multiple installment payment entries.';

                trigger OnAction()
                var
                    CustLedgEntry: Record "Cust. Ledger Entry";
                    ApplyPage: Page "Apply Installment Terms";
                begin
                    if Rec."Installments Applied" then begin
                        Message('Installments have already been applied to invoice %1.', Rec."No.");
                        exit;
                    end;

                    CustLedgEntry.SetRange("Document Type", CustLedgEntry."Document Type"::Invoice);
                    CustLedgEntry.SetRange("Document No.", Rec."No.");
                    CustLedgEntry.SetRange("Customer No.", Rec."Sell-to Customer No.");
                    CustLedgEntry.SetRange(Open, true);
                    if not CustLedgEntry.FindFirst() then begin
                        Message('Invoice %1 is fully paid and cannot be split.', Rec."No.");
                        exit;
                    end;
                    CustLedgEntry.CalcFields("Remaining Amount");

                    ApplyPage.SetContext(
                        Rec."No.",
                        Rec."Sell-to Customer No.",
                        CustLedgEntry."Remaining Amount",
                        Rec."Currency Code",
                        Rec."Posting Date");
                    ApplyPage.RunModal();

                    CurrPage.Update(false);
                end;
            }
        }
    }
}