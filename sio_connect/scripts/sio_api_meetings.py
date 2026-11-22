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
