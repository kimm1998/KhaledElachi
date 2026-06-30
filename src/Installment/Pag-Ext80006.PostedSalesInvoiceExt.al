pageextension 80006 "Posted Sales Invoice Ext" extends "Posted Sales Invoice"
{
    layout
    {
        addafter("Payment Terms Code")
        {
            field("Installments Applied"; Rec."Installments Applied")
            {
                ApplicationArea = All;
                Editable = false;
                StyleExpr = InstAppliedStyle;
                ToolTip = 'Indicates whether installment payment terms have been applied to this invoice.';
            }
            field("Installment Code Applied"; Rec."Installment Code Applied")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'The installment code that was applied to this invoice.';
            }
        }

        addfirst(factboxes)
        {
            part(InstallmentScheduleFactBox; "Installment Schedule FactBox")
            {
                ApplicationArea = All;
                Caption = 'Installment Schedule';
                Visible = ShowInstallmentFactBox;
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
                PromotedIsBig = true;
                Enabled = CanApplyInstallments;
                ToolTip = 'Split this posted invoice into multiple installment payment entries with different due dates.';

                trigger OnAction()
                var
                    CustLedgEntry: Record "Cust. Ledger Entry";
                    ApplyPage: Page "Apply Installment Terms";
                begin
                    CustLedgEntry.SetRange("Document Type", CustLedgEntry."Document Type"::Invoice);
                    CustLedgEntry.SetRange("Document No.", Rec."No.");
                    CustLedgEntry.SetRange("Customer No.", Rec."Sell-to Customer No.");
                    CustLedgEntry.SetRange(Open, true);
                    if not CustLedgEntry.FindFirst() then begin
                        Message('This invoice is fully paid and cannot be split into installments.');
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

            action(ResetInstallments)
            {
                Caption = 'Reset Installments';
                Image = Undo;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = CanResetInstallments;
                ToolTip = 'Remove the applied installment split and restore the original single payment entry. Only allowed if no installments have been paid yet.';

                trigger OnAction()
                var
                    InstallmentApply: Codeunit "Installment Apply to Posted";
                begin
                    if not Confirm(
                        'Reset installments for invoice %1?  This will remove all installment entries and restore the original single payment entry.  This is only allowed if no installments have been paid yet.  Continue?',
                        false, Rec."No.")
                    then
                        exit;

                    InstallmentApply.ResetInstallments(Rec."No.", Rec."Sell-to Customer No.");
                    CurrPage.Update(false);
                    Message('Installments have been reset for invoice %1.', Rec."No.");
                end;
            }

            action(ViewInstallmentLog)
            {
                Caption = 'Installment Log';
                Image = Log;
                ApplicationArea = All;
                ToolTip = 'View the history of installment actions applied to this invoice.';

                trigger OnAction()
                var
                    LogPage: Page "Installment Application Log";
                    LogEntry: Record "Installment Application Log";
                begin
                    LogEntry.SetRange("Document No.", Rec."No.");
                    LogPage.SetTableView(LogEntry);
                    LogPage.Run();
                end;
            }
        }
    }

    var
        CanApplyInstallments: Boolean;
        CanResetInstallments: Boolean;
        ShowInstallmentFactBox: Boolean;
        InstAppliedStyle: Text;

    trigger OnAfterGetRecord()
    var
        CustLedgEntry: Record "Cust. Ledger Entry";
    begin
        CanApplyInstallments := not Rec."Installments Applied";
        CanResetInstallments := Rec."Installments Applied";

        // Show FactBox if applied via flag OR sub-entries exist (e.g. split at posting)
        CustLedgEntry.SetRange("Customer No.", Rec."Sell-to Customer No.");
        CustLedgEntry.SetFilter("Document No.", Rec."No." + '-I*');
        CustLedgEntry.SetRange("Document Type", CustLedgEntry."Document Type"::Invoice);
        ShowInstallmentFactBox := Rec."Installments Applied" or (not CustLedgEntry.IsEmpty());

        if Rec."Installments Applied" then
            InstAppliedStyle := 'Favorable'
        else
            InstAppliedStyle := 'Standard';

        CurrPage.InstallmentScheduleFactBox.Page.SetInvoiceFilter(
            Rec."No.", Rec."Sell-to Customer No.");
    end;
}