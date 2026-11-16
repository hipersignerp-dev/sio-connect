# Schedule a meeting, or (with name) change one: topic, type, date, time, venue, agenda, status, unit.
if not ctx["caps"]["schedule_meeting"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Meeting", name)
    if ctx["scope"] and doc.unit != ctx["scope"]:
        frappe.throw(_("This meeting is for another unit."), frappe.PermissionError)
else:
    doc = frappe.get_doc({"doctype": "SIO Meeting"})
unit = args.get("unit") or doc.unit or ctx["unit"]
if not unit:
    frappe.throw(_("Pick a unit."))
if ctx["scope"] and unit != ctx["scope"]:
    frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
if not (args.get("topic") or "").strip() or not args.get("meeting_date"):
    frappe.throw(_("Enter the topic and date."))
doc.unit = unit
doc.topic = args.get("topic").strip()
doc.meeting_type = args.get("meeting_type") or doc.meeting_type or "Weekly Meeting"
doc.meeting_date = args.get("meeting_date")
doc.meeting_time = args.get("meeting_time") or None
doc.venue = args.get("venue") or None
doc.agenda = args.get("agenda") or None
if args.get("status") in ("Scheduled", "Completed", "Cancelled"):
    doc.status = args.get("status")
if name:
    doc.save(ignore_permissions=True)
else:
    doc.insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name}
