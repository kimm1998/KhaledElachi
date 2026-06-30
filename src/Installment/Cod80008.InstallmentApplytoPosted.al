codeunit 80008 "Installment Apply to Posted"
{
    Permissions = TableData "Sales Invoice Header" = RM;

    procedure ApplyToPostedInvoice(InvoiceNo: Code[20]; CustomerNo: Code[20]; InstallmentCode: Code[20])
    var
        InstallmentJournalMgt: Codeunit "Installment Journal Mgt.";
    begin
        InstallmentJournalMgt.ApplyToPostedInvoice(InvoiceNo, CustomerNo, InstallmentCode, false);
    end;

    procedure ResetInstallments(InvoiceNo: Code[20]; CustomerNo: Code[20])
    var
        InstallmentJournalMgt: Codeunit "Installment Journal Mgt.";
    begin
        InstallmentJournalMgt.ResetInstallments(InvoiceNo, CustomerNo);
    end;
}