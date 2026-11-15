# SIO Member, After Save: give the linked User exactly the SIO roles their role and status call for.
role_map = {
    "Associate": ["SIO Associate"],
    "Member": ["SIO Member"],
    "Unit Secretary": ["SIO Member", "SIO Unit Admin"],
    "Unit President": ["SIO Member", "SIO Unit Admin"],
    "Finance": ["SIO Member", "SIO Finance"],
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
