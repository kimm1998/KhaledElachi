tableextension 80001 "Purch. Header Ext" extends "Purchase Header"
{
    fields
    {
        field(80000; "Requested Prepay Amt Incl. VAT"; Decimal)
        {
            Caption = 'Requested Prepayment Amount (Incl. VAT)';
            DecimalPlaces = 0 : 2;

            trigger OnValidate()
            begin
                UpdatePrepaymentPctFromRequestedAmount();
            end;
        }

        field(80001; "Prepay Paid Amount"; Decimal)
        {
            Caption = 'Prepayment Paid Amount';
            Editable = false;
            DecimalPlaces = 0 : 2;
        }
    }

    local procedure UpdatePrepaymentPctFromRequestedAmount()
    var
        BaseInclVAT: Decimal;
        NewPct: Decimal;
    begin
        // Only meaningful on Purchase Orders
        if Rec."Document Type" <> Rec."Document Type"::Order then
            exit;
        rec.CalcFields("Amount Including VAT");
        BaseInclVAT := Rec."Amount Including VAT";

        if (BaseInclVAT = 0) or (Rec."Requested Prepay Amt Incl. VAT" = 0) then begin
            // Clear prepayment % if no base / no requested amount
            if Rec."Prepayment %" <> 0 then
                Rec.Validate("Prepayment %", 0);
            exit;
        end;

        // % = requested / total * 100
        NewPct := Round((Rec."Requested Prepay Amt Incl. VAT" / BaseInclVAT) * 100, 0.00001);

        // Guard rails (optional)
        if NewPct < 0 then
            NewPct := 0;
        if NewPct > 100 then
            NewPct := 100;

        if Rec."Prepayment %" <> NewPct then
            Rec.Validate("Prepayment %", NewPct);
    end;

    procedure RecalculatePrepayPaidAmount()
    var
        AmtPaid: Decimal;
    begin
        if Rec."Document Type" <> Rec."Document Type"::Order then
            exit;

        AmtPaid := CalcPrepayPaidAmountDocumentCurrency();

        if Rec."Prepay Paid Amount" <> AmtPaid then begin
            Rec."Prepay Paid Amount" := AmtPaid;
            Rec.Modify(true);
        end;
    end;

    local procedure CalcPrepayPaidAmountDocumentCurrency(): Decimal
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        TotalPaid: Decimal;
    begin
        TotalPaid := 0;

        // Find all posted PREPAYMENT purchase invoices that belong to this PO
        // and sum the paid/applied amount against their vendor ledger entries.
        GetPostedPrepaymentInvoicesForOrder(Rec, PurchInvHeader);

        if PurchInvHeader.FindSet() then
            repeat
                TotalPaid += CalcPaidForPostedInvoiceDocumentCurrency(PurchInvHeader);
            until PurchInvHeader.Next() = 0;

        exit(Round(TotalPaid, 0.01));
    end;

    local procedure GetPostedPrepaymentInvoicesForOrder(PurchHeader: Record "Purchase Header"; var PurchInvHeader: Record "Purch. Inv. Header")
    begin
        PurchInvHeader.Reset();

        // =====================================================================
        // TODO (REQUIRED): Implement the link PO -> posted PREPAYMENT invoice(s).
        //
        // This differs by BC version and by what fields are populated for
        // prepayment invoices. Common patterns:
        //
        // A) Via posted invoice lines that reference the order no.
        // B) Via a header field that stores the order no.
        //
        // For now, this function returns no records until you implement it.
        // =====================================================================

        // PurchInvHeader.SetRange("No.", ''); // return empty set by default
        PurchInvHeader.SetRange("Prepayment Order No.", PurchHeader."No.");
    end;

    local procedure CalcPaidForPostedInvoiceDocumentCurrency(PurchInvHeader: Record "Purch. Inv. Header"): Decimal
    var
        VendLedgEntry: Record "Vendor Ledger Entry";
        DtldVendLedgEntry: Record "Detailed Vendor Ledg. Entry";
        Paid: Decimal;
    begin
        Paid := 0;

        // Find the vendor ledger entry for this posted purchase invoice
        VendLedgEntry.Reset();
        VendLedgEntry.SetRange("Document Type", VendLedgEntry."Document Type"::Invoice);
        VendLedgEntry.SetRange("Document No.", PurchInvHeader."No.");
        VendLedgEntry.SetRange("Vendor No.", PurchInvHeader."Pay-to Vendor No.");

        if not VendLedgEntry.FindFirst() then
            exit(0);

        // Sum application amounts that represent payments applied to this invoice entry.
        // We use Detailed Vendor Ledger Entry filtered by the invoice's Vendor Ledger Entry No.
        //
        // NOTE: The exact fields to sum for "document currency" can vary depending on what you
        // consider "paid". This is the most common pattern:
        // - Filter by the invoice's entry no.
        // - Include only application entries.
        //
        DtldVendLedgEntry.Reset();
        DtldVendLedgEntry.SetRange("Vendor Ledger Entry No.", VendLedgEntry."Entry No.");
        DtldVendLedgEntry.SetRange(Unapplied, false);
        DtldVendLedgEntry.SetRange("Entry Type", DtldVendLedgEntry."Entry Type"::Application); 

        // Optional: if you only want payment applications, you can filter further.
        // Depending on your data, you may use:
        // DtldVendLedgEntry.SetRange("Entry Type", DtldVendLedgEntry."Entry Type"::Application);

        if DtldVendLedgEntry.FindSet() then
            repeat
                // IMPORTANT:
                // In many cases the "Amount" on detailed entries is signed.
                // For "paid", we want the magnitude applied that reduces the invoice.
                Paid += Abs(DtldVendLedgEntry.Amount);
            until DtldVendLedgEntry.Next() = 0;

        exit(Paid);
    end;
}