# for_self=1: the signed-in person pledges themselves. Otherwise a collector records someone else's gift.
member = ctx["member"]
camp = frappe.db.get_value("SIO Collection Campaign", {"is_active": 1}, "name", order_by="creation desc")
if args.get("campaign"):
    camp = args.get("campaign")
if not camp or not frappe.db.get_value("SIO Collection Campaign", camp, "is_active"):
    frappe.throw(_("There is no open collection campaign."))
entry_type = args.get("entry_type")
if entry_type not in ("Pledge", "Payment", "In-kind"):
    frappe.throw(_("Unknown entry type."))
paid = frappe.utils.flt(args.get("paid_amount"))
doc = frappe.get_doc({"doctype": "SIO Collection Entry", "campaign": camp, "entry_type": entry_type,
                      "unit": ctx["unit"]})
if frappe.utils.cint(args.get("for_self")):
    if not ctx["caps"]["pledge"]:
        frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
    doc.contributor_name = member.full_name
    doc.contributor_type = "Member" if ctx["is_member"] else "Associate"
    doc.contributor_member = member.name
    doc.contributor_mobile = member.mobile
    paid = 0  # the collector confirms money received later
else:
    if not ctx["caps"]["collect"]:
        frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
    name = (args.get("contributor_name") or "").strip()
    if not name:
        frappe.throw(_("Enter the contributor's name."))
    doc.contributor_name = name
    doc.contributor_type = args.get("contributor_type") or "Well-wisher"
    doc.contributor_mobile = args.get("contributor_mobile")
    doc.collected_by = member.name if member else None
if entry_type == "Pledge":
    doc.pledged_amount = frappe.utils.flt(args.get("pledged_amount"))
    if doc.pledged_amount <= 0:
        frappe.throw(_("Enter the pledged amount."))
elif entry_type == "In-kind":
    doc.in_kind_value = frappe.utils.flt(args.get("in_kind_value"))
    doc.in_kind_details = args.get("in_kind_details")
if entry_type != "In-kind" and paid > 0:
    doc.append("payments", {"payment_date": frappe.utils.nowdate(), "amount": paid,
                            "mode": args.get("payment_mode") or "Cash", "reference_no": args.get("reference_no"),
                            "received_by": doc.collected_by})
if entry_type == "Payment" and paid <= 0:
    frappe.throw(_("Enter the amount received."))
doc.insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name, "status": doc.status}
