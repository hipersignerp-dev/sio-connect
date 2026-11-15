if not ctx["caps"]["approve_expense"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
status = args.get("status")
if status not in ("Approved", "Rejected", "Paid"):
    frappe.throw(_("Unknown status."))
doc = frappe.get_doc("SIO Expense Claim", args.get("name"))
doc.status = status
if args.get("remarks"):
    doc.remarks = args.get("remarks")
if args.get("payment_mode"):
    doc.payment_mode = args.get("payment_mode")
if args.get("paid_from"):
    if not frappe.db.exists("SIO Collection", args.get("paid_from")):
        frappe.throw(_("Pick a collection for Paid From."))
    doc.paid_from = args.get("paid_from")
doc.save(ignore_permissions=True)
frappe.response["message"] = {"status": doc.status}
