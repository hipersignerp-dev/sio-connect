# @include meeting
doc = frappe.get_doc("SIO Meeting", args.get("name"))
area_mtg = is_area_meeting(doc)
if not can_see_meeting(doc):
    frappe.throw(_("This meeting is not for you."), frappe.PermissionError)
can_edit = can_manage_meeting(doc)
out = {
    "name": doc.name, "unit": doc.unit, "area": doc.get("area"), "invite": doc.get("invite"),
    "level": "Area" if area_mtg else "Unit", "where": meeting_place(doc),
    "topic": doc.topic, "meeting_type": doc.meeting_type,
    "meeting_date": doc.meeting_date, "meeting_time": doc.meeting_time, "venue": doc.venue,
    "status": doc.status, "agenda": doc.agenda, "minutes": doc.minutes, "summary": doc.get("summary"),
    "can_edit": can_edit,
    "ai_ready": bool(frappe.db.get_single_value("SIO Settings", "ai_api_key")),
    "present_count": doc.present_count, "total_count": doc.total_count, "my_rsvp": None,
}
rows = {}
for r in doc.attendance:
    rows[r.member] = r
if ctx["member"] and ctx["member"].name in rows:
    out["my_rsvp"] = rows[ctx["member"].name].rsvp
if can_edit and ((area_mtg and ctx["caps"]["schedule_area_meeting"]) or (not area_mtg and ctx["caps"]["mark_attendance"])):
    if area_mtg:
        roster = area_invitees(doc.area, doc.get("invite"))
    else:
        roster = frappe.get_all("SIO Member", filters={"unit": doc.unit, "status": "Active"},
                                fields=["name", "full_name", "unit", "member_role", "photo"], order_by="full_name asc")
    out["roster"] = []
    for m in roster:
        r = rows.get(m.name)
        out["roster"].append({"member": m.name, "full_name": m.full_name, "photo": m.get("photo"),
                              "unit": m.get("unit") if area_mtg else None,
                              "status": r.status if r else "Absent", "rsvp": (r.rsvp if r else "") or ""})
frappe.response["message"] = out
