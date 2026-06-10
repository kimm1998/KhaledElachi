codeunit 80005 "PO Prepayment Enh. Subs"
{
    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", OnAfterInsertEvent, '', false, false)]
    local procedure PurchLine_OnAfterInsert(var Rec: Record "Purchase Line"; RunTrigger: Boolean)
    begin
        UpdateHeaderPct(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", OnAfterModifyEvent, '', false, false)]
    local procedure PurchLine_OnAfterModify(var Rec: Record "Purchase Line"; RunTrigger: Boolean)
    begin
        UpdateHeaderPct(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", OnAfterDeleteEvent, '', false, false)]
    local procedure PurchLine_OnAfterDelete(var Rec: Record "Purchase Line"; RunTrigger: Boolean)
    begin
        UpdateHeaderPct(Rec);
    end;

    local procedure UpdateHeaderPct(PurchLine: Record "Purchase Line")
    var
        PurchHeader: Record "Purchase Header";
    begin
        if PurchLine."Document Type" <> PurchLine."Document Type"::Order then
            exit;

        if PurchLine."Document No." = '' then
            exit;

        if not PurchHeader.Get(PurchLine."Document Type", PurchLine."Document No.") then
            exit;

        if PurchHeader."Requested Prepay Amt Incl. VAT" = 0 then
            exit;

        // Recompute % from requested amount and current total incl. VAT
        PurchHeader.Validate("Requested Prepay Amt Incl. VAT", PurchHeader."Requested Prepay Amt Incl. VAT");
        PurchHeader.Modify(true);
    end;
}