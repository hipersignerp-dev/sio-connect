# Reading leaderboard, no weekly reset: everyone ranked by their current reading streak (with the weekly freeze),
# ties broken by total days read. Three views: everyone, my unit, my friends. My own rank is always returned,
# so a student sees "#112 of 340" and can climb.
# @include journey
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
rows = frappe.db.sql("""select d.member, d.day from `tabSIO Streak Day` d
    join `tabSIO Member` x on x.name = d.member
    where d.activity = 'Reading' and ((x.status = 'Active' and ifnull(x.hide_games, 0) = 0) or x.name = %s)""", (m.name,))
days = {}
for r in rows:
    days.setdefault(r[0], []).append(r[1])
if m.name not in days:
    days[m.name] = []
info = {}
for x in frappe.get_all("SIO Member", filters={"name": ["in", list(days.keys())]},
                        fields=["name", "full_name", "username", "photo", "unit"]):
    info[x.name] = x
people = []
for mid in days:
    s = streak_from_days(days[mid], True)
    x = info.get(mid) or {}
    people.append({"member": mid, "full_name": x.get("full_name"), "username": x.get("username"),
                   "photo": x.get("photo"), "unit": x.get("unit"), "streak": s["current"], "best": s["best"],
                   "total": len(set([str(d) for d in days[mid]])), "today": s["today"], "me": mid == m.name})
people = sorted(people, key=lambda p: (-p["streak"], -p["total"], p["full_name"] or ""))
active = frappe.db.count("SIO Member", {"status": "Active", "hide_games": 0})


def board(lst, limit, out_of):
    mine = None
    for i in range(len(lst)):
        lst[i]["rank"] = i + 1
        if lst[i]["me"]:
            mine = lst[i]
    if mine and mine["streak"] == 0 and mine["total"] == 0:
        mine["rank"] = len([p for p in lst if p["total"] > 0]) + 1
    top = [p for p in lst if p["total"] > 0][:limit]
    return {"top": top, "me": mine, "out_of": out_of}


circle = set(friend_ids(m.name) + [m.name])
unit_people = [dict(p) for p in people if m.unit and p["unit"] == m.unit]
unit_count = frappe.db.count("SIO Member", {"status": "Active", "unit": m.unit}) if m.unit else 0
frappe.response["message"] = {
    "everyone": board([dict(p) for p in people], 100, max(active, len(people))),
    "unit": board(unit_people, 50, max(unit_count, len(unit_people))),
    "friends": board([dict(p) for p in people if p["member"] in circle], 100, len(circle)),
    "unit_name": m.unit,
}
