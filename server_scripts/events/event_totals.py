# SIO Event Registration / SIO Expense Claim, After Save and After Delete: registered count and approved spend.
if doc.event and frappe.db.exists("SIO Event", doc.event):
    registered = frappe.db.count("SIO Event Registration", {"event": doc.event, "status": ["!=", "Cancelled"]})
    spent = frappe.db.sql("""select coalesce(sum(amount), 0) from `tabSIO Expense Claim`
        where event = %s and status in ('Approved', 'Paid')""", doc.event)[0][0]
    frappe.db.set_value("SIO Event", doc.event, {"registered_count": registered, "spent": spent},
                        update_modified=False)
