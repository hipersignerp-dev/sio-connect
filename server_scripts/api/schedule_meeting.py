# Schedule a meeting, or (with name) change one. A unit meeting has a unit; an area meeting (area admins only)
# has the area and "invite" (who is asked to come) instead.
# @include meeting
if not ctx["caps"]["schedule_meeting"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Meeting", name)
    if is_area_meeting(doc) and not ctx["caps"]["schedule_area_meeting"]:
        frappe.throw(_("Only area admins can change area meetings."), frappe.PermissionError)
    if ctx["scope"] and doc.unit != ctx["scope"]:
        frappe.throw(_("This meeting is for another unit."), frappe.PermissionError)
else:
    doc = frappe.get_doc({"doctype": "SIO Meeting"})
level = args.get("level") or ("Area" if is_area_meeting(doc) else "Unit")
if level == "Area":
    if not ctx["caps"]["schedule_area_meeting"]:
        frappe.throw(_("Only area admins can schedule area meetings."), frappe.PermissionError)
    area = args.get("area") or doc.area
    if not area:
        areas = frappe.get_all("SIO Area", pluck="name")
        if len(areas) == 1:
            area = areas[0]
    if not area:
        frappe.throw(_("Pick the area."))
    doc.area = area
    doc.unit = None
    doc.invite = args.get("invite") if args.get("invite") in INVITE_ROLES else (doc.invite or "Unit leaders")
else:
    unit = args.get("unit") or doc.unit or ctx["unit"]
    if not unit:
        frappe.throw(_("Pick a unit."))
    if ctx["scope"] and unit != ctx["scope"]:
        frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
    doc.unit = unit
    doc.area = None
if not (args.get("topic") or "").strip() or not args.get("meeting_date"):
    frappe.throw(_("Enter the topic and date."))
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
