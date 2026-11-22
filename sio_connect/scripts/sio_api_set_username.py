ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Choose my username (3-20 letters, numbers, dot or underscore; unique).
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
u = (args.get("username") or "").strip().lower()
ok = 3 <= len(u) <= 20 and len([c for c in u if c in "abcdefghijklmnopqrstuvwxyz0123456789._"]) == len(u)
if not ok or u[0] in "._":
    frappe.throw(_("Use 3 to 20 letters, numbers, dot or underscore, starting with a letter or number."))
other = frappe.db.get_value("SIO Member", {"username": u}, "name")
if other and other != m.name:
    frappe.throw(_("That username is taken. Try another."))
frappe.db.set_value("SIO Member", m.name, "username", u)
frappe.response["message"] = {"username": u}
