ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Close (no longer needed / filled) or delete a board post: whoever posted it, or the leaders.
m = ctx["member"]
d = frappe.get_doc("SIO Opportunity", args.get("name"))
lead = bool(ctx["caps"]["send_notice"] or ctx["caps"]["manage_events"])
mine = bool(m) and d.posted_by == m.name
if not (mine or (lead and (SCOPE_UNITS is None or d.area == ctx["area"] or not d.area))):
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
if args.get("action") == "delete":
    for f in frappe.get_all("File", filters={"attached_to_doctype": "SIO Opportunity", "attached_to_name": d.name},
                            pluck="name"):
        frappe.get_doc("File", f).delete(ignore_permissions=True)
    frappe.delete_doc("SIO Opportunity", d.name, ignore_permissions=True)
else:
    frappe.db.set_value("SIO Opportunity", d.name, "status", "Closed")
frappe.response["message"] = {"ok": 1}
