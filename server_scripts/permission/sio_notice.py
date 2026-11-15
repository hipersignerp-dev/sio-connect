# SIO Notice: unit presidents / secretaries see only their own unit on the desk. Admins and finance see all.
roles = [r[0] for r in frappe.db.sql(
    "select role from `tabHas Role` where parent=%s and parenttype='User'", user)]
if not (user == "Administrator" or "System Manager" in roles or "SIO Admin" in roles or "SIO Finance" in roles):
    unit = frappe.db.get_value("SIO Member", {"user": user}, "unit") or "__none__"
    conditions = "(ifnull(`tabSIO Notice`.unit, '') = '' or `tabSIO Notice`.unit = " + frappe.db.escape(unit) + ")"
