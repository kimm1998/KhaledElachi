tableextension 80000 "Sales Header Credit Ext." extends "Sales Header"
{
    fields
    {
        field(80000; "Returns Not Invoiced (LCY)"; Decimal)
        {
            Caption = 'Returns Not Invoiced (LCY)';
            FieldClass = FlowField;
            Editable = false;
            // Sums "Amount" (document currency) on open credit memo lines; use "Amount (LCY)" if your version has it.
            CalcFormula = sum("Sales Line".Amount where(
                "Document Type" = const("Credit Memo"),
                "Bill-to Customer No." = field("Bill-to Customer No."),
                "Outstanding Quantity" = filter(<> 0)));
        }
        field(80001; "Exposure (LCY)"; Decimal)
        {
            Caption = 'Exposure (LCY)';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
            ToolTip = 'Balance (LCY) + Shipped Not Invoiced (LCY) - Returns Not Invoiced (LCY).';
        }
        field(80002; "Credit Limit"; Decimal)
        {
            Caption = 'Credit Limit (LCY)';
            Editable = false;
            DecimalPlaces = 2 : 2;
            FieldClass = FlowField;
            CalcFormula = lookup(Customer."Credit Limit (LCY)" where("No." = field("Bill-to Customer No.")));
        }
        field(80003; "Customer Balance"; Decimal)
        {
            Caption = 'Customer Balance (LCY)';
            Editable = false;
            DecimalPlaces = 2 : 2;
            FieldClass = FlowField;
            CalcFormula = sum("Detailed Cust. Ledg. Entry"."Amount (LCY)" where("Customer No." = field("Bill-to Customer No.")));
        }
        field(80004; "Balance Exceeds Credit Limit"; Boolean)
        {
            Caption = 'Balance Exceeds Credit Limit';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(80005; "Exposure Exceeds Credit Limit"; Boolean)
        {
            Caption = 'Exposure Exceeds Credit Limit';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(80006; "Overdue Exceeded"; Boolean)
        {
            Caption = 'Overdue Exceeded';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(80007; "Customer Overdue Balance"; Decimal)
        {
            Caption = 'Customer Overdue Balance (LCY)';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
        }
        field(80009; Exposure; Decimal)
        {
            Caption = 'Exposure (LCY)';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(80010; "Installment Code"; Code[20])
        {
            Caption = 'Installment Code';
            DataClassification = CustomerContent;
            TableRelation = "Installment Payment Terms".Code;
        }
        field(80011; "Outstanding Amount LCY"; Decimal)
        {
            Caption = 'Outstanding Amount (LCY)';
            Editable = false;
            DecimalPlaces = 2 : 2;
            FieldClass = FlowField;
            CalcFormula = sum("Sales Line"."Outstanding Amount (LCY)" where(
                "Document Type" = field("Document Type"),
                "Document No." = field("No.")));
        }
    }
}
