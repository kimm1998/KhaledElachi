tableextension 80000 "Sales Header Credit Ext." extends "Sales Header"
{
    fields
    {
        field(80000; "Returns Not Invoiced (LCY)"; Decimal)
        {
            Caption = 'Returns Not Invoiced (LCY)';
            FieldClass = FlowField;
            Editable = false;

            // Best-effort: open sales credit memo lines (not posted yet).
            // NOTE: Sales Line stores "Amount" (document currency). "Amount (LCY)" exists in some versions; to be safe we sum "Amount".
            // If your environment has "Amount (LCY)" on Sales Line, change CalcFormula to sum that instead.
            CalcFormula = sum("Sales Line".Amount where(
                "Document Type" = const("Credit Memo"),
                "Bill-to Customer No." = field("No."),
                "Outstanding Quantity" = filter(<> 0)
            ));
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
            // DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
            FieldClass = FlowField;
            CalcFormula = lookup("Customer"."Credit Limit (LCY)" where("No." = field("Bill-to Customer No.")));
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
            Editable = false;
        }
        field(80005; "Exposure Exceeds Credit Limit"; Boolean)
        {
            Caption = 'Exposure Exceeds Credit Limit';
            Editable = false;
        }
        field(80006; "Overdue Exceeded"; Boolean)
        {
            Caption = 'Overdue Exceeded';
            Editable = false;
        }
        field(80007; "Customer Overdue Balance"; Decimal)
        {
            Caption = 'Customer Balance (LCY)';
            Editable = false;
            DecimalPlaces = 2 : 2;
            // FieldClass = FlowField;
            // CalcFormula = sum("Detailed Cust. Ledg. Entry"."Amount (LCY)" where("Customer No." = field("Bill-to Customer No."), "Initial Entry Due Date" = field(upperlimit(workdate))));
        }
        field(80009; Exposure; Decimal)
        {
            Caption = 'Exposure (LCY)';
            Editable = false;
        }
        field(80010; "Installment Code"; Code[20])
        {
            Caption = 'Installment Code';
            TableRelation = "Installment Payment Terms".Code;
            DataClassification = CustomerContent;
        }


    }
}