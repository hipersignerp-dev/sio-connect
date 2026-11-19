# Weekly reading leaderboard (Monday to Sunday): days read this week out of 7, for me and my friends, and the
# top readers of my unit. Only the top is shown, so nobody is put at the bottom of a list.
# @include journey
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
today = frappe.utils.getdate(frappe.utils.nowdate())
monday = frappe.utils.add_days(today, -today.weekday())


def week_counts(members):
    if not members:
        return {}
    rows = frappe.db.sql("""select member, count(distinct day), max(day) from `tabSIO Streak Day`
        where activity = 'Reading' and day >= %s and member in %s group by member""", (monday, tuple(members)))
    return dict([(r[0], r[1]) for r in rows])


def person(mid, days):
    x = frappe.db.get_value("SIO Member", mid, ["name", "full_name", "username", "photo", "unit"], as_dict=True) or {}
    return {"member": mid, "full_name": x.get("full_name"), "username": x.get("username"), "photo": x.get("photo"),
            "unit": x.get("unit"), "days": days, "me": mid == m.name,
            "streak": streak_from_days(member_days(mid, "Reading"), True)["current"]}


circle = friend_ids(m.name) + [m.name]
fc = week_counts(circle)
friends = sorted([person(x, fc.get(x, 0)) for x in circle], key=lambda p: (-p["days"], -p["streak"]))
unit = []
if m.unit:
    rows = frappe.db.sql("""select d.member, count(distinct d.day) as n from `tabSIO Streak Day` d
        join `tabSIO Member` x on x.name = d.member
        where d.activity = 'Reading' and d.day >= %s and x.unit = %s and x.status = 'Active'
        group by d.member order by n desc limit 10""", (monday, m.unit))
    unit = sorted([person(r[0], r[1]) for r in rows], key=lambda p: (-p["days"], -p["streak"]))
frappe.response["message"] = {"week_start": monday, "day_of_week": today.weekday() + 1, "friends": friends,
                              "unit": unit, "unit_name": m.unit}
