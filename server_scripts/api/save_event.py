# Add or change an event. Unit admins manage their own unit's events; area admins any event.
if not ctx["caps"]["manage_events"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Event", name)
    if not (in_scope(doc.unit) or (not doc.unit and ctx["caps"]["all_units"]
                                   and (SCOPE_UNITS is None or doc.get("area") == ctx["area"]))):
        frappe.throw(_("You can't change this event."), frappe.PermissionError)
else:
    doc = frappe.get_doc({"doctype": "SIO Event"})
title = (args.get("title") or "").strip()
if not title or not args.get("starts_on"):
    frappe.throw(_("Enter the title and when it starts."))
unit = args.get("unit") or None
if not ctx["caps"]["all_units"]:
    unit = ctx["unit"]  # unit leaders: their own unit only
if unit and not in_scope(unit):
    frappe.throw(_("That unit is not yours."), frappe.PermissionError)
doc.title = title
doc.unit = unit
# area-wide events (no unit) belong to an area; area leaders: their own
doc.area = (frappe.db.get_value("SIO Unit", unit, "district") if unit else None) or \
    (ctx["area"] if SCOPE_UNITS is not None else (args.get("area") or doc.get("area") or ctx["area"]))
doc.event_type = args.get("event_type") or doc.event_type or "Campus Programme"
doc.starts_on = args.get("starts_on")
doc.ends_on = args.get("ends_on") or None
doc.venue = args.get("venue") or None
doc.status = args.get("status") or doc.status or "Planning"
doc.open_to = args.get("open_to") or doc.open_to or "Everyone"
doc.capacity = frappe.utils.cint(args.get("capacity"))
doc.budget = frappe.utils.flt(args.get("budget"))
doc.description = args.get("description") or None
if name:
    doc.save(ignore_permissions=True)
else:
    doc.insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name}
