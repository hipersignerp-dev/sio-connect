# Nudge a friend who hasn't read today: they get "X nudged you 👋". Once a day per friend.
# @include journey
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
other = args.get("member")
if friend_state(m.name, other)["state"] != "friends":
    frappe.throw(_("You can nudge only your friends."))
title = m.full_name + " nudged you 👋"
today = frappe.utils.nowdate()
if frappe.db.exists("SIO Notice", {"member": other, "title": title, "creation": [">=", today]}):
    frappe.response["message"] = {"sent": 0, "already": 1}
else:
    s = streak_from_days(member_days(other, "Reading"), True)
    msg = ("Your " + str(s["current"]) + "-day streak is waiting. Read today's ayah before the day ends 🔥") if s["current"] \
        else "Read today's ayah with me and start a streak together 🔥"
    frappe.get_doc({"doctype": "SIO Notice", "title": title, "message": msg, "audience": "Person",
                    "member": other}).insert(ignore_permissions=True)
    frappe.response["message"] = {"sent": 1}
