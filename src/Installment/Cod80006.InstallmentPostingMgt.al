codeunit 80006 "Installment Posting Mgt."
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterFinalizePosting', '', false, false)]
    local procedure OnAfterFinalizeSalesPosting(
        var SalesHeader: Record "Sales Header";
        var SalesShipmentHeader: Record "Sales Shipment Header";
        var SalesInvoiceHeader: Record "Sales Invoice Header";
        var SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        var ReturnReceiptHeader: Record "Return Receipt Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        PreviewMode: Boolean;
        CommitIsSuppressed: Boolean)
    var
        InstallmentTerms: Record "Installment Payment Terms";
        InstallmentJournalMgt: Codeunit "Installment Journal Mgt.";
    begin
        if PreviewMode then
            exit;

        if CommitIsSuppressed then
            exit;

        if SalesInvoiceHeader."No." = '' then
            exit;

        if SalesInvoiceHeader."Installment Code" = '' then
            exit;

        if not InstallmentTerms.Get(SalesInvoiceHeader."Installment Code") then
            exit;

        InstallmentJournalMgt.ApplyToPostedInvoice(
            SalesInvoiceHeader."No.",
            SalesInvoiceHeader."Sell-to Customer No.",
            SalesInvoiceHeader."Installment Code",
            true);
    end;
}