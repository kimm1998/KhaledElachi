codeunit 80012 Subscribers
{
    Permissions = TableData "Cust. Ledger Entry" = RMID;
    trigger OnRun()
    begin

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Dim Correction Run", 'OnUpdateGLEntryOnAfterUpdateGlobalDimFromDimSetID', '', false, false)]

    local procedure OnUpdateGLEntryOnAfterUpdateGlobalDimFromDimSetID(var GLEntry: Record "G/L Entry")

    var

        CustomerLedgerEntry: Record "Cust. Ledger Entry";

        DetailedCustLedgEntry: Record "Detailed Cust. Ledg. Entry";

    begin

        // Exit if not customer-related GL Entry

        if GLEntry."Source Type" <> GLEntry."Source Type"::Customer then
            exit;
        if GLEntry."Source No." = '' then
            exit;

        if CustomerLedgerEntry.Get(GLEntry."Entry No.") then begin

            CustomerLedgerEntry."Global Dimension 1 Code" := GLEntry."Global Dimension 1 Code";

            CustomerLedgerEntry."Global Dimension 2 Code" := GLEntry."Global Dimension 2 Code";

            CustomerLedgerEntry.Validate("Dimension Set ID", GLEntry."Dimension Set ID");

            if CustomerLedgerEntry.Modify(true) then;

        end;

    end;

    [EventSubscriber(ObjectType::Table, database::"Assembly Header", 'OnBeforeUpdateAssemblyLinesAndVerifyReserveQuantity', '', false, false)]

    local procedure OnBeforeUpdateAssemblyLinesAndVerifyReserveQuantity(var IsHandled: Boolean; var xAssemblyHeader: Record "Assembly Header")//assmenly
    begin
        if xAssemblyHeader.Quantity <> 0 then
            IsHandled := true;
    end;

    var
        myInt: Integer;
}