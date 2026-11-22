# SIO Device Token, After Save: ticking Revoked stops fingerprint sign-in (the user's API secret is replaced).
if doc.revoked and doc.has_value_changed("revoked"):
    u = frappe.get_doc("User", doc.user)
    if u.api_key:
        u.api_secret = frappe.utils.generate_hash(length=15)
        u.save(ignore_permissions=True)
