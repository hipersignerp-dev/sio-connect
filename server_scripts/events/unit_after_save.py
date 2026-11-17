# SIO Unit, After Save: when a unit joins (or leaves) an area, update the desk access of that area's presidents
# and secretaries (User Permissions on SIO Unit).
leads = frappe.get_all("SIO Member", filters={"member_role": ["in", ["Area President", "Area Secretary"]],
                                              "status": "Active", "user": ["is", "set"]},
                       fields=["user", "area"])
for m in leads:
    has = frappe.db.exists("User Permission", {"user": m.user, "allow": "SIO Unit", "for_value": doc.name})
    if m.area and m.area == doc.district and not has:
        frappe.get_doc({"doctype": "User Permission", "user": m.user, "allow": "SIO Unit",
                        "for_value": doc.name, "apply_to_all_doctypes": 1}).insert(ignore_permissions=True)
    elif has and m.area != doc.district:
        frappe.delete_doc("User Permission", has, ignore_permissions=True)
