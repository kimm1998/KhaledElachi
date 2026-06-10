codeunit 80001 "Sales Credit Limit Check"
{
    // ─────────────────────────────────────────────────────────────────────────
    // Single entry point: fires on every Sales-Post run, before anything posts.
    // ─────────────────────────────────────────────────────────────────────────
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
    local procedure OnBeforePostSalesDoc(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean; CommitIsSuppressed: Boolean; var IsHandled: Boolean)
    begin
        // Only act on Sales Orders and Sales Invoices
        ValidateCreditLimitExeed(SalesHeader);
        if not (SalesHeader."Document Type" in [
            SalesHeader."Document Type"::Order,
            SalesHeader."Document Type"::Invoice])
        then
            exit;

        // RunWorkflow1_OverdueVsCreditLimit(SalesHeader);
        // RunWorkflow2_ExposureApproval(SalesHeader);
    end;

    [EventSubscriber(ObjectType::Page, 42, 'OnBeforePostSalesOrder', '', false, false)]
    local procedure OnBeforePostSalesOrder(var SalesHeader: Record "Sales Header")
    begin
        // Only act on Sales Orders and Sales Invoices
        ValidateCreditLimitExeed(SalesHeader);
    end;

    [EventSubscriber(ObjectType::table, 36, 'OnBeforeSendToPosting', '', false, false)]
    local procedure OnBeforeSendToPosting(var SalesHeader: Record "Sales Header")
    begin
        // Only act on Sales Orders and Sales Invoices
        ValidateCreditLimitExeed(SalesHeader);
        SalesHeader.Modify();
    end;

    [EventSubscriber(ObjectType::Page, 43, 'OnPostDocumentBeforeNavigateAfterPosting', '', false, false)]
    local procedure OnPostDocumentBeforeNavigateAfterPosting(var SalesHeader: Record "Sales Header")
    begin
        // Only act on Sales Orders and Sales Invoices
      //  ValidateCreditLimitExeed(SalesHeader);
    end;

    [EventSubscriber(ObjectType::codeunit, 1535, 'OnBeforePrePostApprovalCheckSales', '', false, false)]
    local procedure OnBeforePrePostApprovalCheckSales(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
    var
        int: Integer;
    begin
        int := 1;
         ValidateCreditLimitExeed(SalesHeader);

        if IsSalesHeaderPendingApproval(SalesHeader) then begin
            // if SalesHeader."Balance Exceeds Credit Limit" then
            //     Error(ExceedsCreditLimitErr, SalesHeader."Bill-to Customer No.", SalesHeader."Customer Balance", SalesHeader."Credit Limit")
            // else 
            if SalesHeader."Exposure Exceeds Credit Limit" then
                Error(ExposureNoWorkflowErr, SalesHeader."Bill-to Customer No.", SalesHeader.Exposure, SalesHeader."Credit Limit")
            else if SalesHeader."Overdue Exceeded" then
                Error(OverdueBalanceErr, SalesHeader."Bill-to Customer No.", SalesHeader."Customer Overdue Balance")
            else
                Error(SalesPrePostCheckErr, SalesHeader."Document Type", SalesHeader."No.");
            IsHandled := true;
        end;

    end;

    procedure IsSalesHeaderPendingApproval(var SalesHeader: Record "Sales Header"): Boolean
    begin
        if SalesHeader.Status <> SalesHeader.Status::Open then
            exit(false);

        exit(IsSalesApprovalsWorkflowEnabled(SalesHeader));
    end;

    procedure IsSalesApprovalsWorkflowEnabled(var SalesHeader: Record "Sales Header"): Boolean
    begin
        exit(WorkflowManagement.CanExecuteWorkflow(SalesHeader, WorkflowEventHandling.RunWorkflowOnSendSalesDocForApprovalCode()));
    end;

    // ─────────────────────────────────────────────────────────────────────────
    // WORKFLOW 1 ── Hard block: Overdue Balance > Credit Limit
    // Skipped when Credit Limit = 0 (unlimited).
    // ─────────────────────────────────────────────────────────────────────────
    local procedure RunWorkflow1_OverdueVsCreditLimit(var SalesHeader: Record "Sales Header")
    var
        Customer: Record Customer;
    begin
        Customer.Get(SalesHeader."Bill-to Customer No.");
        Customer.CalcFields("Balance Due (LCY)");

        // Skip: unlimited credit
        if Customer."Credit Limit (LCY)" = 0 then
            exit;

        // Block posting and explain why
        if Customer."Balance Due (LCY)" > Customer."Credit Limit (LCY)" then
            Error(ExceedsCreditLimitErr,
                Customer.Name,
                Customer."Balance Due (LCY)",
                Customer."Credit Limit (LCY)");
    end;

    // ─────────────────────────────────────────────────────────────────────────
    // WORKFLOW 2 ── Approval request: Exposure > Credit Limit
    // Exposure = Balance (LCY) + Shipped Not Invoiced (LCY) - Returns Not Invoiced (LCY)
    // Skipped when Credit Limit = 0 (unlimited).
    // ─────────────────────────────────────────────────────────────────────────
    local procedure RunWorkflow2_ExposureApproval(var SalesHeader: Record "Sales Header")
    var
        Customer: Record Customer;
        SalesCreditLimitMgmt: Codeunit "Sales Credit Limit Mgmt.";
        SalesExposureWkflHandler: Codeunit "Sales Exposure Wkfl. Handler";
        WorkflowManagement: Codeunit "Workflow Management";
        Exposure: Decimal;
    begin
        Customer.Get(SalesHeader."Bill-to Customer No.");

        // Skip: unlimited credit
        if Customer."Credit Limit (LCY)" = 0 then
            exit;

        Exposure := SalesCreditLimitMgmt.CalcExposureLCY(SalesHeader."Bill-to Customer No.");

        // Within limit: nothing to do
        if Exposure <= Customer."Credit Limit (LCY)" then
            exit;

        // Limit exceeded — try to fire the approval workflow
        if WorkflowManagement.CanExecuteWorkflow(
            SalesHeader,
            SalesExposureWkflHandler.RunWorkflowOnExposureOverLimitCode())
        then begin
            WorkflowManagement.HandleEvent(
                SalesExposureWkflHandler.RunWorkflowOnExposureOverLimitCode(),
                SalesHeader);
            // Stop this posting attempt; the document is now Pending Approval
            Error(ExposureApprovalSentMsg,
                Customer.Name,
                Exposure,
                Customer."Credit Limit (LCY)");
        end else
            // No workflow configured: hard block to protect the company
            Error(ExposureNoWorkflowErr,
                Customer.Name,
                Exposure,
                Customer."Credit Limit (LCY)");
    end;

    procedure ValidateCreditLimitExeed(var salesheader: Record "Sales Header")
    var
        Exposure: Decimal;
        SalesCreditLimitMgmt: Codeunit "Sales Credit Limit Mgmt.";
        
    begin
        Exposure := 0;
        CalcOverdueBalance(salesheader);
        salesheader.CalcFields("Customer Balance", "Credit Limit", "Amount Including VAT");
        if salesheader."Credit Limit" = 0 then begin
            if salesheader."Customer Balance" > 0 then
                salesheader."Balance Exceeds Credit Limit" := true
            else
                salesheader."Balance Exceeds Credit Limit" := false;
        end;
        if salesheader."Customer Overdue Balance" > 0 then
            salesheader."Overdue Exceeded" := true
        else
            salesheader."Overdue Exceeded" := false;


        if (salesheader."Customer Balance" + salesheader."Amount Including VAT") > salesheader."Credit Limit" then
            salesheader."Balance Exceeds Credit Limit" := true
        else
            salesheader."Balance Exceeds Credit Limit" := false;

        Exposure := SalesCreditLimitMgmt.CalcExposureLCY(SalesHeader."Bill-to Customer No.");
        salesheader.Exposure := Exposure;
        if salesheader."Credit Limit" <> 0 then
            if (Exposure + salesheader."Amount Including VAT") > salesheader."Credit Limit" then
                salesheader."Exposure Exceeds Credit Limit" := true
            else
                salesheader."Exposure Exceeds Credit Limit" := false;
        // salesheader.Modify();

    end;

    procedure CalcOverdueBalance(var salesheader: Record "Sales Header")
    var
        DetailedCustLedgEntry: Record "Detailed Cust. Ledg. Entry";
    begin
        OverdueBalance := 0;
        if salesheader."Bill-to Customer No." = '' then
            exit;
        DetailedCustLedgEntry.SetRange("Customer No.", salesheader."Bill-to Customer No.");
        // DetailedCustLedgEntry.SetRange("Initial Entry Due Date", 0D, WorkDate());
        DetailedCustLedgEntry.Setfilter("Initial Entry Due Date", '..%1', WorkDate());
        if DetailedCustLedgEntry.FindSet() then
            repeat
                OverdueBalance += DetailedCustLedgEntry."Amount (LCY)";
            until DetailedCustLedgEntry.Next() = 0;
        salesheader."Customer Overdue Balance" := OverdueBalance;
    end;

    var
        ExceedsCreditLimitErr: Label
            'Posting blocked for customer "%1".Reason: The customer''s balance exceeds their credit limit. Balance (LCY) : %2 Credit Limit (LCY)    : %3 Please resolve the outstanding overdue invoices before posting further documents.';
        // Comment = '%1=Customer Name, %2=Overdue Balance LCY, %3=Credit Limit LCY';

        ExposureApprovalSentMsg: Label
            'Posting blocked for customer "%1" — an approval request has been sent. Current Exposure (LCY) : %2, Credit Limit (LCY)     : %3, The document status is now Pending Approval. Posting will resume once the approval is granted.';
        // Comment = '%1=Customer Name, %2=Exposure LCY, %3=Credit Limit LCY';

        ExposureNoWorkflowErr: Label
            'Posting blocked for customer "%1". Current Exposure (LCY): %2, Credit Limit (LCY): %3. The exposure exceeds the credit limit. Please send an approval request.';
        // Comment = '%1=Customer Name, %2=Exposure LCY, %3=Credit Limit LCY';
        SalesPrePostCheckErr: Label 'Sales %1 %2 must be approved and released before you can perform this action.', Comment = '%1=document type, %2=document no., e.g. Sales Order 321 must be approved...';

        OverdueBalanceErr: Label 'Posting blocked for customer "%1". Reason: The customer has overdue invoices. Overdue Balance (LCY): %2. Please settle the overdue amounts or send an approval request before posting further documents.';

        WorkflowManagement: Codeunit "Workflow Management";
        WorkflowEventHandling: Codeunit "Workflow Event Handling";
        OverdueBalance: Decimal;
}