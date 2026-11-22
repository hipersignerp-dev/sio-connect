ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# --- meeting helpers (shared) ---
# A meeting is for one unit (unit set) or for the whole area (area set, unit empty). For area meetings
# "invite" says who is asked to come.
INVITE_ROLES = {
    "Unit leaders": ["Unit President", "Unit Secretary", "Finance", "Area Admin"],
    "All members": ["Unit President", "Unit Secretary", "Finance", "Area Admin", "Member"],
    "Members & workers": ["Unit President", "Unit Secretary", "Finance", "Area Admin", "Member", "Worker"],
    "Everyone": ["Unit President", "Unit Secretary", "Finance", "Area Admin", "Member", "Worker", "Associate"],
}


def is_area_meeting(m):
    return bool(m.get("area")) and not m.get("unit")


def area_invitees(area, invite):
    roles = INVITE_ROLES.get(invite or "Unit leaders") or INVITE_ROLES["Unit leaders"]
    units = frappe.get_all("SIO Unit", filters={"district": area}, pluck="name")
    rows = frappe.get_all("SIO Member", filters={"status": "Active", "member_role": ["in", roles]},
                          fields=["name", "full_name", "unit", "member_role", "photo"], order_by="full_name asc")
    return [r for r in rows if (not r.unit) or r.unit in units]


def invited_to(m, member):
    # can this member (a dict/doc with name, unit, member_role) see / reply to meeting m?
    if not member:
        return False
    if not is_area_meeting(m):
        return m.get("unit") == member.unit
    roles = INVITE_ROLES.get(m.get("invite") or "Unit leaders") or INVITE_ROLES["Unit leaders"]
    if member.member_role not in roles:
        return False
    if not member.unit:
        return True
    return frappe.db.get_value("SIO Unit", member.unit, "district") == m.get("area")


def can_manage_meeting(m):
    # schedule / edit / mark / write the summary
    if is_area_meeting(m):
        return ctx["caps"]["schedule_area_meeting"] and (SCOPE_UNITS is None or m.get("area") == ctx["area"])
    return ctx["caps"]["schedule_meeting"] and in_scope(m.get("unit"))


def can_see_meeting(m):
    if SCOPE_UNITS is None:
        return True
    if is_area_meeting(m):
        return can_manage_meeting(m) or invited_to(m, ctx["member"])
    return in_scope(m.get("unit"))


def meeting_place(m):
    if is_area_meeting(m):
        return m.get("area") + " Area"
    return m.get("unit")
# --- end meeting helpers ---
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
