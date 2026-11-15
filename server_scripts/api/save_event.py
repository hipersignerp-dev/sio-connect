# Add or change an event. Unit admins manage their own unit's events; area admins any event.
if not ctx["caps"]["manage_events"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Event", name)
    if ctx["scope"] and doc.unit != ctx["scope"]:
        frappe.throw(_("Only area admins can change events for all units or other units."), frappe.PermissionError)
else:
    doc = frappe.get_doc({"doctype": "SIO Event"})
title = (args.get("title") or "").strip()
if not title or not args.get("starts_on"):
    frappe.throw(_("Enter the title and when it starts."))
unit = args.get("unit") or None
if ctx["scope"]:
    unit = ctx["scope"]
doc.title = title
doc.unit = unit
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
