# Delete a collection that has no entries yet. One with entries is closed instead, so its records stay.
if not ctx["caps"]["manage_collections"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
n = frappe.db.count("SIO Collection Entry", {"collection": name})
x = frappe.db.count("SIO Expense Claim", {"paid_from": name})
if n or x:
    frappe.throw(_("This collection already has records") + " (" + str(n + x) + "). "
                 + _("Close it instead, so the accounts stay correct."))
frappe.delete_doc("SIO Collection", name, ignore_permissions=True)
frappe.response["message"] = {"deleted": name}
