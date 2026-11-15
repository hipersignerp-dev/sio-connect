# SIO Collection Entry, Before Save: received, balance and status from the payments.
if doc.entry_type == "In-kind":
    doc.set("payments", [])
    doc.paid_amount = 0
    doc.pledged_amount = 0
    doc.balance_amount = 0
    doc.status = "In-kind Received"
else:
    paid = 0
    for p in doc.payments:
        paid += frappe.utils.flt(p.amount)
    doc.paid_amount = paid
    if doc.entry_type == "Payment":
        doc.pledged_amount = paid
    doc.balance_amount = max(frappe.utils.flt(doc.pledged_amount) - paid, 0)
    if paid <= 0:
        doc.status = "Pledged"
    elif paid < frappe.utils.flt(doc.pledged_amount):
        doc.status = "Part Paid"
    else:
        doc.status = "Paid"
