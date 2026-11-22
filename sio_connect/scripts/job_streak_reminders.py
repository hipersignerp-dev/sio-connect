# SIO streak reminders (every evening): people who read yesterday but not yet today are reminded so they don't
# lose their streak.
today = frappe.utils.nowdate()
yesterday = frappe.utils.add_days(today, -1)
rows = frappe.db.sql(
    """select y.member from `tabSIO Streak Day` y
    where y.activity = 'Reading' and y.day = %s and not exists (select 1 from `tabSIO Streak Day` t
        where t.member = y.member and t.activity = 'Reading' and t.day = %s)""", (yesterday, today))
for r in rows:
    frappe.get_doc({"doctype": "SIO Notice", "title": "Keep your streak going 🔥",
                    "message": "Today's ayah / hadith is waiting. Read it in SIO Connect before the day ends.",
                    "audience": "Person", "member": r[0]}).insert(ignore_permissions=True)
