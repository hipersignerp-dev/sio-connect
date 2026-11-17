# @include meeting
member = ctx["member"]
days_back = frappe.utils.cint(args.get("days_back") or 30)
filters = {"meeting_date": [">=", frappe.utils.add_days(frappe.utils.nowdate(), -days_back)],
           "status": ["!=", "Cancelled"]}
if SCOPE_UNITS is not None:
    filters["unit"] = ["in", scope_list()]
fields = ["name", "unit", "area", "invite", "topic", "meeting_type", "meeting_date", "meeting_time", "venue", "status",
          "present_count", "total_count"]
rows = frappe.get_all("SIO Meeting", filters=filters, fields=fields,
                      order_by="meeting_date desc, meeting_time desc", limit=100)
# area meetings: area admins and finance see all; others see the ones they are invited to
afilters = {"meeting_date": filters["meeting_date"], "status": ["!=", "Cancelled"], "area": ["is", "set"],
            "unit": ["is", "not set"]}
for a in frappe.get_all("SIO Meeting", filters=afilters, fields=fields, limit=50):
    if can_see_meeting(a):
        if a.name not in [r.name for r in rows]:
            rows.append(a)
rows = sorted(rows, key=lambda r: (str(r.meeting_date or ""), str(r.meeting_time or "")), reverse=True)
for r in rows:
    r["where"] = meeting_place(r)
    r["level"] = "Area" if is_area_meeting(r) else "Unit"
    r["can_mark"] = can_manage_meeting(r) and (is_area_meeting(r) or ctx["caps"]["mark_attendance"])
mine = {}
if member and rows:
    for a in frappe.get_all("SIO Meeting Attendance",
                            filters={"member": member.name, "parenttype": "SIO Meeting",
                                     "parent": ["in", [r.name for r in rows]]},
                            fields=["parent", "status", "rsvp"]):
        mine[a.parent] = a
today = frappe.utils.getdate(frappe.utils.nowdate())
week_ago = frappe.utils.getdate(frappe.utils.add_days(frappe.utils.nowdate(), -7))
present = 0
total = 0
this_week = 0
to_mark = 0
for r in rows:
    a = mine.get(r.name)
    r["my_status"] = a.status if a else None
    r["my_rsvp"] = a.rsvp if a else None
    d = frappe.utils.getdate(r.meeting_date)
    if d >= week_ago:
        this_week += 1
    if r.status == "Completed" and r.total_count:
        present += frappe.utils.cint(r.present_count)
        total += frappe.utils.cint(r.total_count)
    if r.status == "Scheduled" and d <= today and r["can_mark"]:
        to_mark += 1
frappe.response["message"] = {
    "meetings": rows,
    "summary": {"this_week": this_week, "attendance_pct": round(100.0 * present / max(total, 1)), "to_mark": to_mark},
}
