ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# My event tasks (open ones first, then recently done) and the events whose team I'm on.
member = ctx["member"]
if not member:
    frappe.response["message"] = {"tasks": [], "teams": []}
else:
    tasks = frappe.db.sql(
        """select t.name, t.title, t.responsibility, t.due_on, t.status, t.notes, t.event, e.title as event_title,
            e.starts_on as event_starts, e.venue
        from `tabSIO Event Task` t join `tabSIO Event` e on e.name = t.event
        where t.assigned_to = %(m)s and (t.status != 'Done' or t.done_on >= %(since)s)
        order by (t.status = 'Done'), (t.due_on is null), t.due_on, e.starts_on""",
        {"m": member.name, "since": frappe.utils.add_days(frappe.utils.nowdate(), -30)}, as_dict=True)
    teams = frappe.db.sql(
        """select tm.responsibility, e.name as event, e.title as event_title, e.starts_on as event_starts
        from `tabSIO Event Team Member` tm join `tabSIO Event` e on e.name = tm.parent
        where tm.parenttype = 'SIO Event' and tm.member = %(m)s and e.status not in ('Completed', 'Cancelled')
        order by e.starts_on""", {"m": member.name}, as_dict=True)
    frappe.response["message"] = {"tasks": tasks, "teams": teams}
