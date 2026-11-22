ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# present: JSON list of member IDs who came
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
if not ctx["caps"]["mark_attendance"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
doc = frappe.get_doc("SIO Meeting", args.get("name"))
if not can_manage_meeting(doc):
    frappe.throw(_("You can't mark attendance for this meeting."), frappe.PermissionError)
present = args.get("present") or "[]"
if isinstance(present, str):
    present = json.loads(present)
present = set(present)
existing = {}
for r in doc.attendance:
    existing[r.member] = {"status": r.status, "rsvp": r.rsvp}
if is_area_meeting(doc):
    roster = [m.name for m in area_invitees(doc.area, doc.get("invite"))]
else:
    roster = frappe.get_all("SIO Member", filters={"unit": doc.unit, "status": "Active"}, pluck="name")
members = list(roster) + [m for m in existing if m not in roster]
doc.set("attendance", [])
for m in members:
    old = existing.get(m)
    if m in present:
        status = "Present"
    elif old and old["status"] == "Excused":
        status = "Excused"
    else:
        status = "Absent"
    doc.append("attendance", {"member": m, "status": status, "rsvp": (old["rsvp"] if old else "") or ""})
if args.get("minutes") is not None:
    doc.minutes = args.get("minutes")
if frappe.utils.cint(args.get("complete") if args.get("complete") is not None else 1):
    doc.status = "Completed"
doc.save(ignore_permissions=True)
frappe.response["message"] = {"present": doc.present_count, "total": doc.total_count}
