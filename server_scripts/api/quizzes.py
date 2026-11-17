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
