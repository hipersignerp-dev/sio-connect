# SIO Expense Claim, After Save and After Delete: keep "spent" on the programme fund request it was paid from.
if doc.get("fund_request"):
    spent = frappe.db.sql(
        """select coalesce(sum(amount), 0) from `tabSIO Expense Claim`
        where fund_request = %s and status in ('Approved', 'Paid')""", doc.fund_request)[0][0]
    frappe.db.set_value("SIO Fund Request", doc.fund_request, "spent_amount", frappe.utils.flt(spent))
