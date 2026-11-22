ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# The problems and ideas I sent, with their status and the team's reply (newest first).
rows = frappe.get_all("SIO Feedback", filters={"user": frappe.session.user, "kind": ["!=", "App error"]},
                      fields=["name", "kind", "status", "summary", "message", "reply", "replied_on", "creation"],
                      order_by="creation desc", limit=50)
frappe.response["message"] = rows
