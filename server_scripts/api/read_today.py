# I read today's ayah / hadith: counts towards the reading streak.
# @include journey
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
today = frappe.utils.nowdate()
if not frappe.db.exists("SIO Streak Day", {"member": m.name, "activity": "Reading", "day": today}):
    frappe.get_doc({"doctype": "SIO Streak Day", "member": m.name, "activity": "Reading", "day": today}).insert(
        ignore_permissions=True)
s = streak_from_days(member_days(m.name, "Reading"), True)
s["milestone"] = s["current"] in (3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365)
frappe.response["message"] = s
