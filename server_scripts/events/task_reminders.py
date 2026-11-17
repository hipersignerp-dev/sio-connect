# SIO task reminders (every morning): follow up on open event tasks. A task due within 2 days, or late, gets a
# reminder to its person once a day; a task with no due date gets one when its event is within 3 days.
today = frappe.utils.nowdate()
soon = frappe.utils.add_days(today, 2)
rows = frappe.db.sql(
    """select t.name, t.title, t.assigned_to, t.due_on, t.last_reminded, e.name as event, e.title as event_title,
        e.starts_on
    from `tabSIO Event Task` t join `tabSIO Event` e on e.name = t.event
    where t.status != 'Done' and ifnull(t.assigned_to, '') != '' and e.status not in ('Completed', 'Cancelled')
        and (ifnull(t.last_reminded, '2000-01-01') < %(today)s)
        and ((t.due_on is not null and date(t.due_on) <= %(soon)s)
             or (t.due_on is null and date(e.starts_on) <= %(ev_soon)s and date(e.starts_on) >= %(today)s))""",
    {"today": today, "soon": soon, "ev_soon": frappe.utils.add_days(today, 3)}, as_dict=True)
for r in rows:
    late = r.due_on and frappe.utils.get_datetime(r.due_on) < frappe.utils.now_datetime()
    when = frappe.utils.format_datetime(r.due_on, "EEE d MMM, h:mm a") if r.due_on else ""
    frappe.get_doc({
        "doctype": "SIO Notice",
        "title": ("Overdue: " if late else "Reminder: ") + r.title,
        "message": "For " + r.event_title + (". Was due " if late else ". Due ") + (when or "before the event")
                   + ". Please finish it and mark it done in SIO Connect.",
        "audience": "Person", "member": r.assigned_to, "event": r.event, "task": r.name,
    }).insert(ignore_permissions=True)
    frappe.db.set_value("SIO Event Task", r.name, "last_reminded", today)
