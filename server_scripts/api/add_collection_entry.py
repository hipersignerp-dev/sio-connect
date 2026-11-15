# A new entry in a collection. entry_type: Offer (will pay later), Payment (paid now) or Items.
# for_self=1: the signed-in person makes their own offer. Otherwise a collector records someone else's.
member = ctx["member"]
visible = [c["name"] for c in run_script("SIO lib collections").sio_collections]
collection = args.get("collection") or (visible[0] if visible else None)
if not collection or collection not in visible:
    frappe.throw(_("Pick an open collection."))
entry_type = args.get("entry_type")
if entry_type not in ("Offer", "Payment", "Items"):
    frappe.throw(_("Unknown entry type."))
paid = frappe.utils.flt(args.get("paid_amount"))
# Which unit this money counts for: your own unit; finance and area admins pick any unit.
unit = ctx["unit"]
if ctx["caps"]["all_units"] and args.get("unit"):
    unit = args.get("unit")
    if not frappe.db.exists("SIO Unit", unit):
        frappe.throw(_("Pick a unit from the list."))
if not unit and not frappe.utils.cint(args.get("for_self")):
    frappe.throw(_("Pick the unit this collection is for."))
doc = frappe.get_doc({"doctype": "SIO Collection Entry", "collection": collection, "entry_type": entry_type,
                      "unit": unit})
if frappe.utils.cint(args.get("for_self")):
    if not ctx["caps"]["offer"]:
        frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
    if entry_type != "Offer":
        frappe.throw(_("Give your offer; the collector marks it paid when you pay."))
    doc.contributor_name = member.full_name
    doc.contributor_type = "Member" if ctx["is_member"] else "Associate"
    doc.contributor_member = member.name
    doc.contributor_mobile = member.mobile
    paid = 0
else:
    if not ctx["caps"]["collect"]:
        frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
    name = (args.get("contributor_name") or "").strip()
    if not name:
        frappe.throw(_("Enter the name of the person giving."))
    doc.contributor_name = name
    doc.contributor_type = args.get("contributor_type") or "Well-wisher"
    doc.contributor_mobile = "".join([c for c in (args.get("contributor_mobile") or "") if c.isdigit() or c == "+"]) or None
    doc.contributor_place = (args.get("contributor_place") or "").strip() or None
    doc.collected_by = member.name if member else None
if entry_type == "Offer":
    doc.offered_amount = frappe.utils.flt(args.get("offered_amount"))
    if doc.offered_amount <= 0:
        frappe.throw(_("Enter the amount offered."))
elif entry_type == "Items":
    doc.items_given = args.get("items_given")
    doc.items_value = frappe.utils.flt(args.get("items_value"))
    if not (doc.items_given or "").strip():
        frappe.throw(_("Enter the items given."))
if entry_type != "Items" and paid > 0:
    doc.append("payments", {"payment_date": frappe.utils.nowdate(), "amount": paid,
                            "mode": args.get("payment_mode") or "Cash", "reference_no": args.get("reference_no"),
                            "received_by": doc.collected_by})
if entry_type == "Payment" and paid <= 0:
    frappe.throw(_("Enter the amount received."))
doc.insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name, "status": doc.status}
