if not ctx["caps"]["approve_members"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
doc = frappe.get_doc("SIO Member", args.get("name"))
if ctx["scope"] and doc.unit != ctx["scope"]:
    frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
if args.get("action") == "reject":
    doc.status = "Rejected"
else:
    role = args.get("member_role") or "Associate"
    if not ctx["is_admin"] and role not in ("Associate", "Member"):
        frappe.throw(_("Only area admins can give that role."), frappe.PermissionError)
    doc.status = "Active"
    doc.member_role = role
doc.save(ignore_permissions=True)
frappe.response["message"] = {"status": doc.status, "member_role": doc.member_role}
