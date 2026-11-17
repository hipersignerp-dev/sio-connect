if not ctx["caps"]["collect"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
member = ctx["member"]
doc = frappe.get_doc("SIO Collection Entry", args.get("entry"))
mine = member and doc.collected_by == member.name
if not mine:
    if not (ctx["is_unit_admin"] or ctx["is_finance"]):
        frappe.throw(_("Only the collector or the unit admin can add payments."), frappe.PermissionError)
    if not in_scope(doc.unit):
        frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
amount = frappe.utils.flt(args.get("amount"))
if amount <= 0:
    frappe.throw(_("Enter the amount."))
doc.append("payments", {"payment_date": frappe.utils.nowdate(), "amount": amount, "mode": args.get("mode") or "Cash",
                        "reference_no": args.get("reference_no"), "received_by": member.name if member else None})
doc.save(ignore_permissions=True)
frappe.response["message"] = {"status": doc.status, "paid_amount": doc.paid_amount, "balance_amount": doc.balance_amount}
