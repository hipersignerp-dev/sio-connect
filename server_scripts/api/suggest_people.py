# People you may know: active members of my unit, then my area, who aren't friends yet (and no request pending).
# @include journey
m = ctx["member"]
out = []
if m:
    taken = set([r[0] for r in frappe.db.sql(
        """select if(requester = %s, addressee, requester) from `tabSIO Friend`
        where requester = %s or addressee = %s""", (m.name, m.name, m.name))])
    taken.add(m.name)
    area = ctx["area"] or "__none__"
    rows = frappe.db.sql(
        """select name, full_name, username, photo, unit, member_role from `tabSIO Member`
        where status = 'Active' and (unit = %s or area = %s)
        order by (unit = %s) desc, (ifnull(username, '') != '') desc, (ifnull(photo, '') != '') desc, full_name
        limit 60""", (m.unit or "__none__", area, m.unit or "__none__"), as_dict=True)
    for r in rows:
        if r.name in taken:
            continue
        c = card(r)
        c["reading"] = streak_from_days(member_days(r.name, "Reading"), True)["current"]
        c["same_unit"] = r.unit == m.unit
        out.append(c)
        if len(out) >= 20:
            break
frappe.response["message"] = out
