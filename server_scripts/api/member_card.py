# My SIO membership card: photo, name, unit, area, ID, since when, and the QR leaders scan at programmes.
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
d = frappe.db.get_value("SIO Member", m.name, ["name", "full_name", "photo", "unit", "area", "member_role", "status",
                                               "joined_on", "creation", "campus", "username"], as_dict=True)
role = d.member_role
nice = {"Associate": "Student", "Worker": "Student", "Member": "SIO Member", "Area Admin": "Area Team"}.get(role, role)
since = frappe.utils.getdate(d.joined_on or d.creation).year
attended = frappe.db.count("SIO Event Registration", {"member": d.name, "status": "Attended"})
frappe.response["message"] = {
    "member": d.name, "full_name": d.full_name, "photo": d.photo, "unit": d.unit, "area": d.area, "role": nice,
    "status": d.status, "since": since, "campus": d.campus, "username": d.username, "programmes": attended,
    "qr": "SIOMEMBER:" + d.name,
}
