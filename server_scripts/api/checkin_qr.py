# The check-in QR for a programme (leaders who run it). Students scan it to mark themselves present.
# @include tasks
ev = frappe.get_doc("SIO Event", args.get("event"))
if not (can_manage_event(ev) or is_coordinator(ev.name)):
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
if not ev.get("checkin_code") or frappe.utils.cint(args.get("new")):
    frappe.db.set_value("SIO Event", ev.name, "checkin_code", frappe.utils.generate_hash(length=10))
code = frappe.db.get_value("SIO Event", ev.name, "checkin_code")
present = frappe.db.count("SIO Event Registration", {"event": ev.name, "status": "Attended"})
registered = frappe.db.count("SIO Event Registration", {"event": ev.name, "status": ["!=", "Cancelled"]})
frappe.response["message"] = {"qr": "SIOCHECKIN:" + ev.name + ":" + code, "title": ev.title, "present": present,
                              "registered": registered}
