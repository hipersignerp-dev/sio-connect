# Continue with Google (guest). Known email: signs in and returns a token for this phone. New email: returns
# their Google name/email so the app can show the short sign-up form (register with google_token).
# @include google
f = frappe.form_dict
g = google_identity(f.get("id_token"))
user = frappe.db.get_value("User", {"name": g["email"]}, ["name", "enabled"], as_dict=True)
if not user:
    m = frappe.db.get_value("SIO Member", {"email": g["email"], "user": ["is", "set"]}, "user")
    if m:
        user = frappe.db.get_value("User", m, ["name", "enabled"], as_dict=True)
if user:
    if not user.enabled:
        frappe.throw(_("This account is turned off. Contact your unit."))
    frappe.response["message"] = {"token": issue_token(user.name, f.get("device_name")), "user": user.name}
else:
    frappe.response["message"] = {"new": 1, "email": g["email"], "full_name": g["name"]}
