# SIO Member: on the desk, unit presidents / secretaries see only their own unit; area presidents / secretaries the
# units of their area. Admins and finance see all.
roles = [r[0] for r in frappe.db.sql(
    "select role from `tabHas Role` where parent=%s and parenttype='User'", user)]
if not (user == "Administrator" or "System Manager" in roles or "SIO Admin" in roles or "SIO Finance" in roles):
    m = frappe.db.get_value("SIO Member", {"user": user}, ["unit", "area", "member_role"], as_dict=True) or {}
    if m.get("member_role") in ("Area President", "Area Secretary") and m.get("area"):
        units = [u[0] for u in frappe.db.sql("select name from `tabSIO Unit` where district = %s", m.get("area"))]
    else:
        units = [m.get("unit")] if m.get("unit") else []
    inlist = ", ".join([frappe.db.escape(u) for u in units]) or "'__none__'"
    conditions = "`tabSIO Member`.unit in (" + inlist + ")"
