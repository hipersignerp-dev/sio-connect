ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Turn off fingerprint sign-in: replace the secret so the phone's copy stops working.
u = frappe.get_doc("User", ctx["user"])
if u.api_key:
    u.api_secret = frappe.utils.generate_hash(length=15)
    u.save(ignore_permissions=True)
for name in frappe.get_all("SIO Device Token", filters={"user": ctx["user"], "revoked": 0}, pluck="name"):
    frappe.db.set_value("SIO Device Token", name, "revoked", 1)
frappe.response["message"] = {"ok": True}
