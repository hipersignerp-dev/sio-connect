# Fingerprint sign-in: give this phone an API key + secret. The phone keeps them in its secure storage,
# behind the fingerprint, and sends them as a token. One secret per user: a new phone replaces the old one.
u = frappe.get_doc("User", ctx["user"])
if not u.api_key:
    u.api_key = frappe.utils.generate_hash(length=15)
secret = frappe.utils.generate_hash(length=15)
u.api_secret = secret
u.save(ignore_permissions=True)
for name in frappe.get_all("SIO Device Token", filters={"user": ctx["user"], "revoked": 0}, pluck="name"):
    frappe.db.set_value("SIO Device Token", name, "revoked", 1)
frappe.get_doc({
    "doctype": "SIO Device Token",
    "user": ctx["user"],
    "device_name": (args.get("device_name") or "Phone")[:140],
    "token_hash": frappe.utils.sha256_hash(secret),
    "last_used": frappe.utils.now_datetime(),
}).insert(ignore_permissions=True)
frappe.response["message"] = {"api_key": u.api_key, "api_secret": secret}
