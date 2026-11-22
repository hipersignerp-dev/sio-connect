ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Schedule a meeting, or (with name) change one. A unit meeting has a unit; an area meeting (area admins only)
# has the area and "invite" (who is asked to come) instead.
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
if not ctx["caps"]["schedule_meeting"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Meeting", name)
    if not can_manage_meeting(doc):
        frappe.throw(_("You can't change this meeting."), frappe.PermissionError)
else:
    doc = frappe.get_doc({"doctype": "SIO Meeting"})
level = args.get("level") or ("Area" if is_area_meeting(doc) else "Unit")
if level == "Area":
    if not ctx["caps"]["schedule_area_meeting"]:
        frappe.throw(_("Only area leaders can schedule area meetings."), frappe.PermissionError)
    area = args.get("area") or doc.area or ctx["area"]
    if SCOPE_UNITS is not None:
        area = ctx["area"]  # area presidents / secretaries: their own area only
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
    if not in_scope(unit):
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
