codeunit 80004 "INT Approval Request Processor"
{
    SingleInstance = false;
    

    procedure TryProcessEntry(var Req: Record "INT Approval Request")
    begin
        // Wrap processing so API insert doesn't hard-fail on business errors;
        // instead write Error/Last Error on the intermediate table.
        if not ProcessEntry(Req) then begin
            // nothing else; ProcessEntry already wrote error state
        end;
    end;

    procedure ProcessEntry(var Req: Record "INT Approval Request"): Boolean
    var
        SalesHeader: Record "Sales Header";
        DocType: Enum "Sales Document Type";
        ErrTxt: Text;
    begin
        ClearLastError();
        Req."Last Error" := '';
        Req."Processed At" := 0DT;

        if Req."Document No." = '' then
            exit(SetError(Req, 'Document No. is required.'));

        if not TryMapToSalesHeaderType(Req."Document Type", DocType, ErrTxt) then
            exit(SetError(Req, ErrTxt));

        if DocType <> DocType::Order then
            exit(SetError(Req, StrSubstNo('Approvals are supported only for Sales Orders. Document Type "%1" is not supported.', Req."Document Type")));

        SalesHeader.Reset();
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange("No.", Req."Document No.");
        if not SalesHeader.FindFirst() then
            exit(SetError(Req, StrSubstNo('Sales Order not found in BC. No.=%1', Req."Document No.")));

        Req."Sales Document SystemId" := SalesHeader.SystemId;

        // Trigger approval request for the sales order
        if not TrySendSalesDocForApproval(SalesHeader, ErrTxt) then
            exit(SetError(Req, ErrTxt));

        Req.Status := Req.Status::Processed;
        Req."Processed At" := CurrentDateTime();
        Req.Modify(true);

        exit(true);
    end;

    local procedure TryMapToSalesHeaderType(DocumentTypeTxt: Text; var DocType: Enum "Sales Document Type"; var ErrTxt: Text): Boolean
    var
        Normalized: Text;
    begin
        Normalized := LowerCase(DelChr(Format(DocumentTypeTxt), '=', ' '));

        // Accept a few common variants since SF is sending text.
        if (Normalized = 'order') or (Normalized = 'salesorder') or (Normalized = 'sales order') then begin
            DocType := DocType::Order;
            exit(true);
        end;

        if (Normalized = 'invoice') or (Normalized = 'salesinvoice') or (Normalized = 'sales invoice') then begin
            DocType := DocType::Invoice;
            exit(true);
        end;

        ErrTxt := StrSubstNo('Unsupported Document Type "%1". Expected e.g. "Order".', DocumentTypeTxt);
        exit(false);
    end;

    local procedure TrySendSalesDocForApproval(var SalesHeader: Record "Sales Header"; var ErrTxt: Text): Boolean
    var
        ApprovalsMgmt: Codeunit "Approvals Mgmt.";
    begin
        // Some tenants may have different approval setup; use try to avoid hard-crash.
        ClearLastError();
        if not TryCallSendForApproval(SalesHeader) then begin
            ErrTxt := GetLastErrorText();
            if ErrTxt = '' then
                ErrTxt := 'Failed to send approval request (unknown error).';
            exit(false);
        end;

        exit(true);
    end;

    [TryFunction]
    local procedure TryCallSendForApproval(var SalesHeader: Record "Sales Header")
    var
        ApprovalsMgmt: Codeunit "Approvals Mgmt.";
    begin
        if ApprovalsMgmt.CheckSalesApprovalPossible(SalesHeader) then
            ApprovalsMgmt.OnSendSalesDocForApproval(SalesHeader);
    end;

    local procedure SetError(var Req: Record "INT Approval Request"; ErrorText: Text): Boolean
    begin
        Req.Status := Req.Status::Error;
        Req."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(Req."Last Error"));
        Req."Processed At" := CurrentDateTime();
        Req.Modify(true);
        exit(false);
    end;
}