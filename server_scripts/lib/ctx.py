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
        ["name", "full_name", "mobile", "email", "member_role", "status", "unit", "campus", "course",
         "year_of_study", "home_town", "joined_on"],
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
    "view_collection_totals": is_unit_admin or is_finance,
    "approve_expense": is_finance or len(approver_units) > 0,
    "send_notice": is_unit_admin,
    "all_units": is_admin or is_finance,
    "view_accounts": is_unit_admin or is_finance,
    "manage_collections": is_admin or is_finance,
    "manage_events": is_unit_admin,
    "add_members": is_unit_admin,
    "manage_units": is_admin,
    "view_donors": is_unit_admin or is_finance or is_member,
    "request_funds": is_unit_admin and member is not None,
    "approve_funds": is_finance,
}

scope = None  # None = every unit
if not (is_admin or is_finance):
    scope = unit or "__none__"

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
    "member_role": role_label,
    "status": status,
    "unit": unit,
    "mobile": member.mobile if member else None,
    "email": member.email if member else user,
    "campus": member.campus if member else None,
    "course": member.course if member else None,
    "year_of_study": member.year_of_study if member else None,
    "home_town": member.home_town if member else None,
    "joined_on": member.joined_on if member else None,
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
    "approver_units": approver_units,
    "me": me,
}
