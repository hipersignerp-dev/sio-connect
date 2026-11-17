# Check in at a programme. A student scans the programme's QR (code = SIOCHECKIN:<event>:<secret>), or a
# leader scans a student's card (code = SIOMEMBER:<member>, event = the programme). Marks them Attended.
# @include tasks
code = (args.get("code") or "").strip()
m = ctx["member"]
if code.startswith("SIOCHECKIN:"):
    parts = code.split(":")
    if len(parts) != 3:
        frappe.throw(_("This QR code is not a SIO programme code."))
    ev = frappe.db.get_value("SIO Event", parts[1], ["name", "title", "status", "starts_on", "ends_on",
                                                       "checkin_code"], as_dict=True)
    if not ev or not ev.checkin_code or ev.checkin_code != parts[2]:
        frappe.throw(_("This check-in code is not valid any more. Ask the organisers to show it again."))
    if not m:
        frappe.throw(_("Your student record is not set up yet."))
    who = m.name
    by_leader = False
elif code.startswith("SIOMEMBER:"):
    ev = frappe.db.get_value("SIO Event", args.get("event"), ["name", "title", "status", "starts_on", "ends_on"],
                             as_dict=True)
    if not ev:
        frappe.throw(_("Pick the programme first."))
    if not (can_manage_event(frappe.get_doc("SIO Event", ev.name)) or is_coordinator(ev.name)):
        frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
    who = code.split(":", 1)[1]
    if not frappe.db.exists("SIO Member", who):
        frappe.throw(_("This card is not a SIO member card."))
    by_leader = True
else:
    frappe.throw(_("This QR code is not a SIO code."))
if ev.status == "Cancelled":
    frappe.throw(_("This programme was cancelled."))
today = frappe.utils.getdate(frappe.utils.nowdate())
start = frappe.utils.getdate(ev.starts_on) if ev.starts_on else today
end = frappe.utils.getdate(ev.ends_on) if ev.ends_on else start
if frappe.utils.date_diff(start, today) > 1 or frappe.utils.date_diff(today, end) > 1:
    frappe.throw(_("Check-in is open only around the day of the programme."))
reg = frappe.db.get_value("SIO Event Registration", {"event": ev.name, "member": who}, ["name", "status"], as_dict=True)
already = bool(reg) and reg.status == "Attended"
first = frappe.db.count("SIO Event Registration", {"member": who, "status": "Attended"}) == 0
if reg:
    if not already:
        frappe.db.set_value("SIO Event Registration", reg.name, "status", "Attended")
else:
    frappe.get_doc({"doctype": "SIO Event Registration", "event": ev.name, "member": who,
                    "status": "Attended"}).insert(ignore_permissions=True)
p = frappe.db.get_value("SIO Member", who, ["full_name", "photo", "unit"], as_dict=True)
frappe.response["message"] = {"event": ev.name, "title": ev.title, "already": already, "first": first and not already,
                              "member": who, "full_name": p.full_name, "photo": p.photo, "unit": p.unit,
                              "by_leader": by_leader,
                              "present": frappe.db.count("SIO Event Registration",
                                                         {"event": ev.name, "status": "Attended"})}
