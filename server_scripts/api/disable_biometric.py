# Turn off fingerprint sign-in: replace the secret so the phone's copy stops working.
u = frappe.get_doc("User", ctx["user"])
if u.api_key:
    u.api_secret = frappe.utils.generate_hash(length=15)
    u.save(ignore_permissions=True)
for name in frappe.get_all("SIO Device Token", filters={"user": ctx["user"], "revoked": 0}, pluck="name"):
    frappe.db.set_value("SIO Device Token", name, "revoked", 1)
frappe.response["message"] = {"ok": True}
