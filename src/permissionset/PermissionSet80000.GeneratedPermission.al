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
        page "INT Approval Requests API"=X;
}