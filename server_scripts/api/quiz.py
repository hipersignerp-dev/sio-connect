# A quiz to take (args: name, or the current one). Answers are only sent after it is taken.
m = ctx["member"]
name = args.get("name")
if not name:
    today = frappe.utils.nowdate()
    area = frappe.db.get_value("SIO Member", m.name, "area") if m else None
    r = frappe.db.sql(
        """select name from `tabSIO Quiz` where starts_on <= %s and ends_on >= %s
        and (ifnull(area, '') = '' or area = %s) order by starts_on desc limit 1""", (today, today, area or "__none__"))
    if not r:
        frappe.response["message"] = None
        frappe.response["docs"] = []
    name = r[0][0] if r else None
if name:
    q = frappe.get_doc("SIO Quiz", name)
    att = frappe.db.get_value("SIO Quiz Attempt", {"quiz": q.name, "member": m.name if m else "__none__"},
                              ["score", "total", "answers"], as_dict=True)
    done = att is not None
    out = {"name": q.name, "title": q.title, "ends_on": q.ends_on, "done": done,
           "score": att.score if att else None, "total": att.total if att else None,
           "my_answers": json.loads(att.answers or "[]") if att else [],
           "questions": []}
    leader = ctx["caps"]["manage_events"] and frappe.utils.cint(args.get("edit"))
    if leader:
        out["starts_on"] = q.starts_on
    for x in q.questions:
        item = {"question": x.question, "options": [o for o in [x.option_a, x.option_b, x.option_c, x.option_d] if o]}
        if done or leader:
            item["correct"] = "ABCD".index(x.correct)
            item["explanation"] = x.explanation
        out["questions"].append(item)
    frappe.response["message"] = out
