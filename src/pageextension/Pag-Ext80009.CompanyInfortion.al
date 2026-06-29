pageextension 80009 CompanyInfo extends "Company Information"
{
    layout
    {
        // Add changes to page layout here
        addlast(general)
        {
            field("API Country"; Rec."API Country")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the API Country for the company.';
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
}