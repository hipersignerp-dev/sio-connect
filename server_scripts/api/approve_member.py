if not ctx["caps"]["approve_members"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
doc = frappe.get_doc("SIO Member", args.get("name"))
if not in_scope(doc.unit):
    frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
if args.get("action") == "reject":
    doc.status = "Rejected"
else:
    role = args.get("member_role") or "Associate"
    # unit admins make Associates and Workers; becoming an official Member (after Mulakath, books...) and
    # office roles are given by area admins
    if not ctx["is_admin"]:
        allowed = ["Associate", "Worker", "Member", "Unit Secretary", "Unit President"] if ctx["is_area_lead"] \
            else ["Associate", "Worker"]
        if role not in allowed:
            frappe.throw(_("You can't give that role."), frappe.PermissionError)
    doc.status = "Active"
    doc.member_role = role
doc.save(ignore_permissions=True)
frappe.response["message"] = {"status": doc.status, "member_role": doc.member_role}
