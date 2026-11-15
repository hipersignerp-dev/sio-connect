if not ctx["caps"]["schedule_meeting"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
unit = args.get("unit") or ctx["unit"]
if not unit:
    frappe.throw(_("Pick a unit."))
if ctx["scope"] and unit != ctx["scope"]:
    frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
if not (args.get("topic") or "").strip() or not args.get("meeting_date"):
    frappe.throw(_("Enter the topic and date."))
doc = frappe.get_doc({
    "doctype": "SIO Meeting",
    "unit": unit,
    "topic": args.get("topic").strip(),
    "meeting_type": args.get("meeting_type") or "Weekly Meeting",
    "meeting_date": args.get("meeting_date"),
    "meeting_time": args.get("meeting_time"),
    "venue": args.get("venue"),
    "agenda": args.get("agenda"),
}).insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name}
