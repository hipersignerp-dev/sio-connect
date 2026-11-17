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
