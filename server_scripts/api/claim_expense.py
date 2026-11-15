if not ctx["caps"]["claim_expense"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
amount = frappe.utils.flt(args.get("amount"))
if amount <= 0 or not (args.get("description") or "").strip():
    frappe.throw(_("Enter what it was for and the amount."))
doc = frappe.get_doc({
    "doctype": "SIO Expense Claim",
    "description": args.get("description").strip(),
    "amount": amount,
    "category": args.get("category") or "Other",
    "expense_date": args.get("expense_date") or frappe.utils.nowdate(),
    "event": args.get("event") or None,
    "paid_from": args.get("paid_from") or None,
    "unit": ctx["unit"],
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
