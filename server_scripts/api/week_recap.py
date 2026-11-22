# My week (Monday to today): days read, streak, programmes attended, photos I'm in, reactions on my photos,
# friends added. For the Home recap card and the shareable picture.
# @include journey
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
today = frappe.utils.getdate(frappe.utils.nowdate())
monday = frappe.utils.add_days(today, -today.weekday())
days = member_days(m.name, "Reading")
read = len([d for d in set([str(jday(x)) for x in days]) if d >= str(monday)])
s = streak_from_days(days, True)
progs = frappe.db.sql("""select e.title from `tabSIO Event Registration` r join `tabSIO Event` e on e.name = r.event
    where r.member = %s and r.status = 'Attended' and date(e.starts_on) >= %s""", (m.name, monday))
photos = frappe.db.count("SIO Photo Tag", {"member": m.name, "creation": [">=", monday]})
mine = frappe.get_all("SIO Photo Tag", filters={"member": m.name}, pluck="photo", limit=500)
reacts = frappe.db.count("SIO Photo Reaction", {"photo": ["in", mine or ["-"]], "member": ["!=", m.name],
                                                "creation": [">=", monday]})
friends = frappe.db.sql("""select count(*) from `tabSIO Friend` where status = 'Accepted' and modified >= %s
    and (requester = %s or addressee = %s)""", (monday, m.name, m.name))[0][0]
frappe.response["message"] = {"week_start": monday, "day_of_week": today.weekday() + 1, "days_read": read,
                              "streak": s["current"], "best": s["best"], "programmes": [p[0] for p in progs],
                              "photos": photos, "reactions": reacts, "new_friends": friends,
                              "name": m.full_name, "unit": m.unit}
