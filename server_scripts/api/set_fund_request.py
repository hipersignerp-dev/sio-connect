# Area finance decides on a fund request: approve (full or part), reject, release the money, or close it.
caps = ctx["caps"]
if not caps["approve_funds"]:
    frappe.throw(_("Only finance or area admins can decide fund requests."), frappe.PermissionError)
doc = frappe.get_doc("SIO Fund Request", args.get("name"))
action = args.get("action")
if args.get("remarks"):
    doc.remarks = args.get("remarks")
if action == "approve":
    if doc.status not in ("Pending", "Approved"):
        frappe.throw(_("This request has already been decided."))
    amt = frappe.utils.flt(args.get("approved_amount")) or frappe.utils.flt(doc.amount_requested)
    if amt <= 0:
        frappe.throw(_("Enter the amount approved."))
    doc.approved_amount = amt
    doc.status = "Approved"
    doc.approved_by = frappe.session.user
elif action == "reject":
    if doc.status not in ("Pending", "Approved"):
        frappe.throw(_("Money for this request has already been released."))
    doc.status = "Rejected"
    doc.approved_by = frappe.session.user
elif action == "release":
    if doc.status not in ("Pending", "Approved"):
        frappe.throw(_("This request can't be released now."))
    if doc.status == "Pending":
        doc.approved_by = frappe.session.user
    amt = frappe.utils.flt(args.get("released_amount")) or frappe.utils.flt(doc.approved_amount) \
        or frappe.utils.flt(doc.amount_requested)
    if amt <= 0:
        frappe.throw(_("Enter the amount released."))
    if not doc.approved_amount:
        doc.approved_amount = amt
    doc.released_amount = amt
    doc.released_on = args.get("released_on") or frappe.utils.nowdate()
    doc.payment_mode = args.get("payment_mode") or "Cash"
    paid_from = args.get("paid_from") or None
    if paid_from and not frappe.db.exists("SIO Collection", paid_from):
        frappe.throw(_("Pick a collection for Paid From."))
    doc.paid_from = paid_from
    doc.status = "Released"
elif action == "close":
    if doc.status != "Released":
        frappe.throw(_("Only released requests can be closed."))
    doc.status = "Closed"
else:
    frappe.throw(_("Unknown action."))
doc.save(ignore_permissions=True)
frappe.response["message"] = {"status": doc.status}
