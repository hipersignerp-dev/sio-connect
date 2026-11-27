# I read today's ayah / hadith: counts towards the reading streak.
# @include journey
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
today = frappe.utils.nowdate()
first_time = not frappe.db.exists("SIO Streak Day", {"member": m.name, "activity": "Reading", "day": today})
if not frappe.db.exists("SIO Streak Day", {"member": m.name, "activity": "Reading", "day": today}):
    frappe.get_doc({"doctype": "SIO Streak Day", "member": m.name, "activity": "Reading", "day": today}).insert(
        ignore_permissions=True)
s = streak_from_days(member_days(m.name, "Reading"), True)
s["milestone"] = s["current"] in (3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365)
# the reading series: did this lesson finish a themed week? Then the chest opens with a new pot colour for Noor.
rows, weeks = reading_series()
st = series_state(m.name, rows, weeks)
s["lessons"] = st["done"]
n = len(rows) or 1
at = st["done"] % n or n
for w in weeks:
    if first_time and st["done"] > 0 and w["start"] + w["size"] == at:
        s["week_done"] = w
        done_weeks = st["completed_weeks"]  # including this one
        if done_weeks < len(POTS):
            s["new_pot"] = POTS[done_weeks]
frappe.response["message"] = s
