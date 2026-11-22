ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Delete an event nobody registered for and with no expenses; otherwise mark it Cancelled instead.
if not ctx["caps"]["manage_events"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
doc = frappe.get_doc("SIO Event", name)
if not in_scope(doc.unit):
    frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
n = frappe.db.count("SIO Event Registration", {"event": name})
x = frappe.db.count("SIO Expense Claim", {"event": name})
if n or x:
    frappe.throw(_("This event has registrations or expenses. Set its status to Cancelled instead."))
frappe.delete_doc("SIO Event", name, ignore_permissions=True)
frappe.response["message"] = {"deleted": name}
