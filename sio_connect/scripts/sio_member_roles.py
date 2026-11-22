# SIO Member, After Save: give the linked User exactly the SIO roles their role and status call for.
role_map = {
    "Associate": ["SIO Associate"],
    "Worker": ["SIO Member"],
    "Member": ["SIO Member"],
    "Unit Secretary": ["SIO Member", "SIO Unit Admin"],
    "Unit President": ["SIO Member", "SIO Unit Admin"],
    "Finance": ["SIO Member", "SIO Finance"],
    "Area President": ["SIO Member", "SIO Unit Admin"],
    "Area Secretary": ["SIO Member", "SIO Unit Admin"],
    "Area Admin": ["SIO Member", "SIO Unit Admin", "SIO Finance", "SIO Admin"],
}
sio_roles = ["SIO Associate", "SIO Member", "SIO Unit Admin", "SIO Finance", "SIO Admin"]
if doc.user and frappe.db.exists("User", doc.user):
    if doc.status == "Active":
        wanted = set(role_map.get(doc.member_role) or ["SIO Associate"])
    elif doc.status == "Pending Approval":
        wanted = set(["SIO Associate"])
    else:
        wanted = set()
    user = frappe.get_doc("User", doc.user)
    have = set([r.role for r in user.roles if r.role in sio_roles])
    enabled = 0 if doc.status == "Rejected" else 1
    if have != wanted or user.enabled != enabled:
        keep = [{"role": r.role} for r in user.roles if r.role not in sio_roles]
        user.set("roles", keep + [{"role": r} for r in sorted(wanted)])
        user.enabled = enabled
        user.save(ignore_permissions=True)

# On the desk, unit presidents and secretaries are tied to their own unit, and area presidents and secretaries
# to the units of their area (User Permissions on SIO Unit), so they can't open other units' records.
if doc.user and frappe.db.exists("User", doc.user):
    want = []
    if doc.status == "Active" and doc.member_role in ("Unit President", "Unit Secretary") and doc.unit:
        want = [doc.unit]
    elif doc.status == "Active" and doc.member_role in ("Area President", "Area Secretary") and doc.get("area"):
        want = frappe.get_all("SIO Unit", filters={"district": doc.area}, pluck="name") or []
    for up in frappe.get_all("User Permission", filters={"user": doc.user, "allow": "SIO Unit"},
                             fields=["name", "for_value"]):
        if up.for_value not in want:
            frappe.delete_doc("User Permission", up.name, ignore_permissions=True)
    for u in want:
        if not frappe.db.exists("User Permission", {"user": doc.user, "allow": "SIO Unit", "for_value": u}):
            frappe.get_doc({"doctype": "User Permission", "user": doc.user, "allow": "SIO Unit",
                            "for_value": u, "apply_to_all_doctypes": 1}).insert(ignore_permissions=True)
