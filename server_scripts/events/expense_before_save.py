# SIO Expense Claim, Before Save: who approved, date paid.
if not doc.is_new() and doc.has_value_changed("status") and doc.status in ("Approved", "Rejected"):
    doc.approved_by = frappe.session.user
if doc.status == "Paid" and not doc.paid_on:
    doc.paid_on = frappe.utils.today()
