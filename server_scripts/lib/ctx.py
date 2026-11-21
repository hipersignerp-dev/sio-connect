# SIO lib ctx: who is calling and what they may do.
# Other SIO scripts call:  ctx = run_script("SIO lib ctx").sio_ctx
user = frappe.session.user
roles = []
if user != "Guest":
    roles = [r[0] for r in frappe.db.sql(
        "select role from `tabHas Role` where parent=%s and parenttype='User'", user)]
is_admin = user == "Administrator" or "System Manager" in roles or "SIO Admin" in roles
is_finance = is_admin or "SIO Finance" in roles
is_unit_admin = is_admin or "SIO Unit Admin" in roles

member = None
if user != "Guest":
    member = frappe.db.get_value(
        "SIO Member", {"user": user},
        ["name", "full_name", "photo", "mobile", "email", "member_role", "status", "unit", "area", "campus", "course",
         "year_of_study", "home_town", "joined_on", "latitude", "longitude", "location_note", "username", "life_stage",
         "profession", "workplace", "current_city", "mentor_topics", "phone_visibility", "hide_games"],
        as_dict=True)

if member:
    status = member.status
elif is_admin:
    status = "Active"
else:
    status = "None"
active = status == "Active"
is_member = active and (is_unit_admin or is_finance or "SIO Member" in roles)
unit = member.unit if member else None

# Who sees what. Area admins (overall admins) and finance see every unit. Area presidents and secretaries see
# the units of their own area. Everyone else sees only their own unit.
AREA_ROLES = ("Area President", "Area Secretary")
area = None
if member:
    area = member.get("area") or (frappe.db.get_value("SIO Unit", unit, "district") if unit else None)
is_area_lead = bool(member) and active and member.member_role in AREA_ROLES and not (is_admin or is_finance)
if is_admin or is_finance:
    units = None  # every unit
elif is_area_lead:
    units = [u[0] for u in frappe.db.sql("select name from `tabSIO Unit` where district = %s", area or "__none__")]
elif unit:
    units = [unit]
else:
    units = []
# units whose expense approver this person is
approver_units = []
if member:
    approver_units = [u[0] for u in frappe.db.sql(
        "select name from `tabSIO Unit` where expense_approver = %s", member.name)]

caps = {
    "rsvp": active and member is not None,
    "register_events": status in ("Active", "Pending Approval") and member is not None,
    "offer": status in ("Active", "Pending Approval") and member is not None,
    "collect": is_member,
    "claim_expense": is_member and member is not None,
    "view_members": is_unit_admin,
    "approve_members": is_unit_admin,
    "mark_attendance": is_unit_admin,
    "schedule_meeting": is_unit_admin,
    "schedule_area_meeting": is_admin or is_area_lead,
    "view_collection_totals": is_unit_admin or is_finance,
    "approve_expense": is_finance or is_area_lead or len(approver_units) > 0,
    "send_notice": is_unit_admin,
    "all_units": is_admin or is_finance or is_area_lead,  # works across more than one unit
    "view_accounts": is_unit_admin or is_finance,
    "manage_collections": is_admin or is_finance or is_area_lead,
    "manage_events": is_unit_admin,
    "add_members": is_unit_admin,
    "manage_units": is_admin or is_area_lead,
    "view_donors": is_unit_admin or is_finance or is_member,
    "request_funds": is_unit_admin and member is not None,
    "approve_funds": is_finance or is_area_lead,
}

# Old single-unit scope, kept so nothing can widen by mistake: None = every unit; a unit name; or for area
# leads a value that matches no unit (scripts use units / in_scope instead).
scope = None
if units is not None:
    scope = unit if (unit and not is_area_lead) else "__area__"

if member:
    role_label = member.member_role
elif is_admin:
    role_label = "Area Admin"
else:
    role_label = None

me = {
    "user": user,
    "full_name": member.full_name if member else frappe.get_fullname(user),
    "member": member.name if member else None,
    "photo": member.get("photo") if member else None,
    "member_role": role_label,
    "status": status,
    "unit": unit,
    "area": area,
    "level": "all" if units is None else ("area" if is_area_lead else "unit"),
    "mobile": member.mobile if member else None,
    "email": member.email if member else user,
    "campus": member.campus if member else None,
    "course": member.course if member else None,
    "year_of_study": member.year_of_study if member else None,
    "home_town": member.home_town if member else None,
    "latitude": member.latitude if member else None,
    "longitude": member.longitude if member else None,
    "location_note": member.location_note if member else None,
    "joined_on": member.joined_on if member else None,
    "username": member.username if member else None,
    "life_stage": member.life_stage if member else None,
    "profession": member.profession if member else None,
    "workplace": member.workplace if member else None,
    "current_city": member.current_city if member else None,
    "mentor_topics": member.mentor_topics if member else None,
    "phone_visibility": (member.phone_visibility or "Leaders only") if member else None,
    "hide_games": 1 if (member and member.hide_games) else 0,
    "capabilities": caps,
    "approver_units": approver_units,
}

frappe.flags.sio_ctx = {
    "user": user,
    "member": member,
    "status": status,
    "active": active,
    "unit": unit,
    "is_admin": is_admin,
    "is_finance": is_finance,
    "is_unit_admin": is_unit_admin,
    "is_member": is_member,
    "caps": caps,
    "scope": scope,
    "units": units,
    "area": area,
    "is_area_lead": is_area_lead,
    "approver_units": approver_units,
    "me": me,
}
