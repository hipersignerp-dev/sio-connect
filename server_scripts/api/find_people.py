# Find people by username or name to add as friends.
# @include journey
m = ctx["member"]
q = (args.get("q") or "").strip().lower().lstrip("@")
if len(q) < 2:
    frappe.response["message"] = []
else:
    like = "%" + q + "%"
    rows = frappe.db.sql(
        """select name, full_name, username, photo, unit, member_role from `tabSIO Member`
        where status = 'Active' and name != %(me)s and (username like %(q)s or full_name like %(q)s)
        order by (username = %(exact)s) desc, full_name limit 30""",
        {"q": like, "me": m.name if m else "__none__", "exact": q}, as_dict=True)
    out = []
    for r in rows:
        c = card(r)
        c["friend"] = friend_state(m.name, r.name)["state"] if m else "none"
        out.append(c)
    frappe.response["message"] = out
