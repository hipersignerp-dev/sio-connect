# A unit asks the area for money to run a programme.
caps = ctx["caps"]
if not caps["request_funds"]:
    frappe.throw(_("Only unit presidents and secretaries can ask for programme funds."), frappe.PermissionError)
title = (args.get("title") or "").strip()
purpose = (args.get("purpose") or "").strip()
amount = frappe.utils.flt(args.get("amount_requested"))
if not title or not purpose or amount <= 0:
    frappe.throw(_("Enter the programme, what it is for and the amount."))
unit = ctx["unit"]
if caps["all_units"] and args.get("unit"):
    unit = args.get("unit")
    if not in_scope(unit):
        frappe.throw(_("That unit is not in your area."), frappe.PermissionError)
if not unit:
    frappe.throw(_("Pick the unit asking for the money."))
event = args.get("event") or None
if event:
    ev_unit = frappe.db.get_value("SIO Event", event, "unit")
    if ev_unit and ev_unit != unit:
        frappe.throw(_("That event belongs to another unit."))
doc = frappe.get_doc({
    "doctype": "SIO Fund Request",
    "title": title,
    "unit": unit,
    "event": event,
    "needed_by": args.get("needed_by") or None,
    "amount_requested": amount,
    "purpose": purpose,
    "breakdown": (args.get("breakdown") or "").strip() or None,
    "requested_by": ctx["member"].name,
    "status": "Pending",
}).insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name, "status": doc.status}
