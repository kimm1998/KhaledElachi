namespace KAPermissions;

permissionset 80000 GeneratedPermission
{
    Assignable = true;
    Permissions = codeunit "Sales Credit Limit Check"=X,
        codeunit "Sales Credit Limit Mgmt."=X,
        codeunit "Sales Exposure Wkfl. Handler"=X,
        tabledata "INT Approval Request"=RIMD,
        table "INT Approval Request"=X,
        codeunit "Approval Webhook Mgt."=X,
        codeunit "Approvals Mgmt"=X,
        codeunit "INT Approval Request Processor"=X,
        codeunit "PO Prepayment Enh. Subs"=X,
        codeunit ResetJobQueueEntry=X,
        codeunit Subscribers=X,
        codeunit WorkflowApprovalMgt=X,
        page ApprovalReq=X,
        page "INT Approval Requests API"=X,
        tabledata "Installment Application Log"=RIMD,
        tabledata "Installment Payment Terms"=RIMD,
        tabledata "Installment Preview Line"=RIMD,
        tabledata "Installment Terms Line"=RIMD,
        table "Installment Application Log"=X,
        table "Installment Payment Terms"=X,
        table "Installment Preview Line"=X,
        table "Installment Terms Line"=X,
        codeunit "Installment Apply to Posted"=X,
        codeunit "Installment Journal Mgt."=X,
        codeunit "Installment Posting Mgt."=X,
        page "Apply Installment Terms"=X,
        page "Installment Application Log"=X,
        page "Installment Payment Terms"=X,
        page "Installment Payment Terms Card"=X,
        page "Installment Preview Lines"=X,
        page "Installment Schedule FactBox"=X,
        page "Installment Terms Subpage"=X;
}