doc = frappe.get_doc("SIO Meeting", args.get("name"))
if not (ctx["is_admin"] or ctx["is_finance"]) and doc.unit != ctx["unit"]:
    frappe.throw(_("This meeting is for another unit."), frappe.PermissionError)
out = {
    "name": doc.name, "unit": doc.unit, "topic": doc.topic, "meeting_type": doc.meeting_type,
    "meeting_date": doc.meeting_date, "meeting_time": doc.meeting_time, "venue": doc.venue,
    "status": doc.status, "agenda": doc.agenda, "minutes": doc.minutes, "summary": doc.get("summary"),
    "can_edit": ctx["caps"]["schedule_meeting"] and (not ctx["scope"] or doc.unit == ctx["scope"]),
    "ai_ready": bool(frappe.db.get_single_value("SIO Settings", "ai_api_key")),
    "present_count": doc.present_count, "total_count": doc.total_count, "my_rsvp": None,
}
rows = {}
for r in doc.attendance:
    rows[r.member] = r
if ctx["member"] and ctx["member"].name in rows:
    out["my_rsvp"] = rows[ctx["member"].name].rsvp
if ctx["caps"]["mark_attendance"]:
    roster = frappe.get_all("SIO Member", filters={"unit": doc.unit, "status": "Active"},
                            fields=["name", "full_name"], order_by="full_name asc")
    out["roster"] = []
    for m in roster:
        r = rows.get(m.name)
        out["roster"].append({"member": m.name, "full_name": m.full_name,
                              "status": r.status if r else "Absent", "rsvp": (r.rsvp if r else "") or ""})
frappe.response["message"] = out
