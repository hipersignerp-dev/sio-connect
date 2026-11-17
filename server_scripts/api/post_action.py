# Cheer a post (toggle) or delete it (its owner, or the leaders of their unit / area).
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
p = frappe.get_doc("SIO Post", args.get("name"))
if args.get("action") == "delete":
    if p.member != m.name and not (ctx["caps"]["approve_members"] and in_scope(p.unit)):
        frappe.throw(_("You can't delete this post."), frappe.PermissionError)
    for c in frappe.get_all("SIO Post Cheer", filters={"post": p.name}, pluck="name"):
        frappe.delete_doc("SIO Post Cheer", c, ignore_permissions=True)
    frappe.delete_doc("SIO Post", p.name, ignore_permissions=True)
    frappe.response["message"] = {"deleted": 1}
else:
    c = frappe.db.get_value("SIO Post Cheer", {"post": p.name, "member": m.name}, "name")
    if c:
        frappe.delete_doc("SIO Post Cheer", c, ignore_permissions=True)
    else:
        frappe.get_doc({"doctype": "SIO Post Cheer", "post": p.name, "member": m.name}).insert(ignore_permissions=True)
    n = frappe.db.count("SIO Post Cheer", {"post": p.name})
    frappe.db.set_value("SIO Post", p.name, "cheers", n)
    if not c and p.member != m.name:
        frappe.get_doc({"doctype": "SIO Notice", "title": m.full_name + " cheered your post", "message": p.title,
                        "audience": "Person", "member": p.member}).insert(ignore_permissions=True)
    frappe.response["message"] = {"cheers": n, "my_cheer": not c}
