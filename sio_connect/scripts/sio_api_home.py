ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

caps = ctx["caps"]
member = ctx["member"]
notices = run_script("SIO lib notices", limit=3).sio_notices
out = {"me": ctx["me"], "next_meeting": None, "next_event": None, "notices": notices}
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

mfields = ["name", "topic", "meeting_type", "meeting_date", "meeting_time", "venue", "unit", "area", "invite"]
upcoming = []
if ctx["unit"]:
    upcoming = frappe.get_all(
        "SIO Meeting",
        filters={"unit": ctx["unit"], "status": "Scheduled", "meeting_date": [">=", frappe.utils.nowdate()]},
        fields=mfields, order_by="meeting_date asc, meeting_time asc", limit=1)
for a in frappe.get_all("SIO Meeting", filters={"area": ["is", "set"], "unit": ["is", "not set"], "status": "Scheduled",
                                                "meeting_date": [">=", frappe.utils.nowdate()]},
                        fields=mfields, order_by="meeting_date asc, meeting_time asc", limit=5):
    if can_see_meeting(a):
        upcoming.append(a)
        break
upcoming = sorted(upcoming, key=lambda r: (str(r.meeting_date or ""), str(r.meeting_time or "")))
if True:
    rows = upcoming
    if rows:
        mt = rows[0]
        mt["where"] = meeting_place(mt)
        mt["my_rsvp"] = None
        if member:
            mt["my_rsvp"] = frappe.db.get_value(
                "SIO Meeting Attendance", {"parent": mt.name, "parenttype": "SIO Meeting", "member": member.name}, "rsvp")
        out["next_meeting"] = mt
    if member:
        att = frappe.db.sql(
            """select count(*), sum(a.status = 'Present') from `tabSIO Meeting Attendance` a
            join `tabSIO Meeting` m on m.name = a.parent
            where a.member = %s and m.status = 'Completed' and m.meeting_date >= %s""",
            (member.name, frappe.utils.add_days(frappe.utils.nowdate(), -180)))[0]
        out["my_attendance"] = {"total": frappe.utils.cint(att[0]), "present": frappe.utils.cint(att[1])}

events = run_script("SIO lib events", upcoming_only=1, limit=1).sio_events
if events:
    out["next_event"] = events[0]

collections = [c for c in run_script("SIO lib collections").sio_collections if c["phase"] == "Running"]
out["collections"] = [{"name": c["name"], "collection_type": c["collection_type"], "totals": c["totals"]}
                      for c in collections]
out["my_offers"] = {"offered": sum([c["my_offered"] for c in collections]),
                    "paid": sum([c["my_paid"] for c in collections])}
if caps["view_members"]:
    base = {}
    if SCOPE_UNITS is not None:
        base["unit"] = ["in", scope_list()]
    active_f = dict(base)
    active_f["status"] = "Active"
    pending_f = dict(base)
    pending_f["status"] = "Pending Approval"
    out["members"] = {"active": frappe.db.count("SIO Member", active_f),
                      "pending": frappe.db.count("SIO Member", pending_f)}
if caps["approve_expense"]:
    if ctx["is_finance"]:
        pend = frappe.db.sql(
            "select count(*), coalesce(sum(amount), 0) from `tabSIO Expense Claim` where status = 'Pending'")[0]
    else:
        pend = frappe.db.sql(
            """select count(*), coalesce(sum(amount), 0) from `tabSIO Expense Claim`
            where status = 'Pending' and unit in %(u)s""",
            {"u": tuple(list(ctx["approver_units"]) + ((SCOPE_UNITS or []) if ctx["is_area_lead"] else [])
                        or ["__none__"])})[0]
    out["pending_expenses"] = {"count": frappe.utils.cint(pend[0]), "amount": frappe.utils.flt(pend[1])}
if SCOPE_UNITS is None:
    pub = frappe.db.get_value("SIO Settings", "SIO Settings", "public_collection")
    if pub:
        out["public_to_confirm"] = frappe.db.count("SIO Collection Entry",
                                                   {"collection": pub, "status": "Offered", "payment_ref": ["is", "set"]})
if caps["approve_funds"]:
    out["pending_funds"] = frappe.db.count("SIO Fund Request", {"status": "Pending"})
if member:
    out["my_tasks"] = frappe.db.count("SIO Event Task", {"assigned_to": member.name, "status": ["!=", "Done"]})
frappe.response["message"] = out
