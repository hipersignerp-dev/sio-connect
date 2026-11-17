# Find SIO members anywhere: by name / @username / place (unit, area, college, home town, landmark), or near me.
# Without a search it returns the places to browse (units, colleges, home towns) with how many members each has.
# Only public details go out (no phone, no exact location: distance is rounded).
# @include journey
m = ctx["member"]
me_name = m.name if m else "__none__"
q = (args.get("q") or "").strip().lstrip("@")
place = (args.get("place") or "").strip()
kind = args.get("kind") or ""
lat = frappe.utils.flt(args.get("lat"))
lng = frappe.utils.flt(args.get("lng"))
near = bool(lat or lng)
fields = "name, full_name, username, photo, unit, area, member_role, campus, course, home_town"
if not q and not place and not near:
    def counts(col):
        return [{"place": r[0], "members": r[1]} for r in frappe.db.sql(
            "select " + col + ", count(*) from `tabSIO Member` where status = 'Active' and ifnull(" + col + ", '') != '' "
            "group by " + col + " order by count(*) desc, " + col + " limit 40")]
    frappe.response["message"] = {"places": {"Unit": counts("unit"), "Area": counts("area"), "College": counts("campus"),
                                             "Home town": counts("home_town")},
                                  "total": frappe.db.count("SIO Member", {"status": "Active"})}
else:
    conds = ["status = 'Active'", "name != %(me)s"]
    params = {"me": me_name}
    if q:
        conds.append("(full_name like %(q)s or username like %(q)s or unit like %(q)s or area like %(q)s "
                     "or campus like %(q)s or home_town like %(q)s or location_note like %(q)s or course like %(q)s)")
        params["q"] = "%" + q + "%"
    col = {"Unit": "unit", "Area": "area", "College": "campus", "Home town": "home_town"}.get(kind)
    if place and col:
        conds.append(col + " = %(place)s")
        params["place"] = place
    dist = "null"
    order = "(ifnull(photo, '') != '') desc, full_name"
    if near:
        params["lat"] = lat
        params["lng"] = lng
        dist = ("6371 * acos(least(1, cos(radians(%(lat)s)) * cos(radians(latitude)) * cos(radians(longitude) - "
                "radians(%(lng)s)) + sin(radians(%(lat)s)) * sin(radians(latitude))))")
        conds.append("ifnull(latitude, 0) != 0 and ifnull(longitude, 0) != 0")
        order = "distance"
    rows = frappe.db.sql("select " + fields + ", " + dist + " as distance from `tabSIO Member` where "
                         + " and ".join(conds) + " order by " + order + " limit 80", params, as_dict=True)
    if near:
        rows = [r for r in rows if r.distance is not None and r.distance <= frappe.utils.flt(args.get("km") or 25)]
    friends = set(friend_ids(m.name)) if m else set()
    pend = {}
    if m:
        for r in frappe.db.sql("""select requester, addressee from `tabSIO Friend` where status = 'Pending'
                and (requester = %s or addressee = %s)""", (m.name, m.name)):
            pend[r[1] if r[0] == m.name else r[0]] = "sent" if r[0] == m.name else "received"
    out = []
    for r in rows:
        c = card(r)
        c["area"] = r.area
        c["campus"] = r.campus
        c["course"] = r.course
        c["home_town"] = r.home_town
        if r.distance is not None:
            d = frappe.utils.flt(r.distance)
            c["distance"] = 0.5 if d < 1 else round(d) if d >= 10 else round(d, 1)
        c["friend"] = "friends" if r.name in friends else pend.get(r.name, "none")
        out.append(c)
    frappe.response["message"] = {"people": out}
