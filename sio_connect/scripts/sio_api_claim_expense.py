ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

if not ctx["caps"]["claim_expense"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
amount = frappe.utils.flt(args.get("amount"))
if amount <= 0 or not (args.get("description") or "").strip():
    frappe.throw(_("Enter what it was for and the amount."))
fund_request = args.get("fund_request") or None
if fund_request:
    fr = frappe.db.get_value("SIO Fund Request", fund_request, ["status", "unit", "event"], as_dict=True)
    if not fr or fr.status != "Released":
        frappe.throw(_("Pick a fund request whose money has been released."))
    if not in_scope(fr.unit):
        frappe.throw(_("That fund request belongs to another unit."), frappe.PermissionError)
doc = frappe.get_doc({
    "doctype": "SIO Expense Claim",
    "description": args.get("description").strip(),
    "amount": amount,
    "category": args.get("category") or "Other",
    "expense_date": args.get("expense_date") or frappe.utils.nowdate(),
    "event": args.get("event") or None,
    "paid_from": None,
    "fund_request": fund_request,
    "unit": fr.unit if fund_request else ctx["unit"],
    "claimed_by": ctx["member"].name,
}).insert(ignore_permissions=True)
if args.get("bill_data"):
    f = frappe.get_doc({
        "doctype": "File",
        "file_name": args.get("bill_filename") or (doc.name + "-bill.jpg"),
        "attached_to_doctype": "SIO Expense Claim",
        "attached_to_name": doc.name,
        "attached_to_field": "bill",
        "is_private": 1,
        "content": args.get("bill_data"),
        "decode": True,
    })
    f.insert(ignore_permissions=True)
    frappe.db.set_value("SIO Expense Claim", doc.name, "bill", f.file_url)
frappe.response["message"] = {"name": doc.name}
