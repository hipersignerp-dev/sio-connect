ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Quizzes for leaders to manage (with how many took each and the average score).
if not (ctx["caps"]["manage_events"]):
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
rows = frappe.db.sql(
    """select q.name, q.title, q.starts_on, q.ends_on, q.area,
        (select count(*) from `tabSIO Quiz Question` x where x.parent = q.name and x.parenttype = 'SIO Quiz') as questions,
        (select count(*) from `tabSIO Quiz Attempt` a where a.quiz = q.name) as attempts,
        (select avg(a.score / nullif(a.total, 0)) * 100 from `tabSIO Quiz Attempt` a where a.quiz = q.name) as avg_pct
    from `tabSIO Quiz` q order by q.starts_on desc limit 60""", as_dict=True)
frappe.response["message"] = rows
