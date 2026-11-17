# @include journey
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
    out["prize"] = q.get("prize")
    # leaderboard: me and my friends, and the top of my area
    board = []
    if m:
        who = friend_ids(m.name) + [m.name]
        for a in frappe.get_all("SIO Quiz Attempt", filters={"quiz": q.name, "member": ["in", who]},
                                fields=["member", "score", "total", "creation"]):
            c = frappe.db.get_value("SIO Member", a.member, ["full_name", "photo", "username"], as_dict=True) or {}
            board.append({"member": a.member, "full_name": c.get("full_name"), "photo": c.get("photo"),
                          "username": c.get("username"), "score": a.score, "total": a.total, "me": a.member == m.name,
                          "at": str(a.creation)})
    out["friends_board"] = sorted(board, key=lambda x: (-(x["score"] or 0), x["at"]))
    top = frappe.db.sql("""select a.member, a.score, a.total, x.full_name, x.photo, x.unit from `tabSIO Quiz Attempt` a
        join `tabSIO Member` x on x.name = a.member where a.quiz = %s order by a.score desc, a.creation asc limit 5""",
                        q.name, as_dict=True)
    out["top"] = top
    out["takers"] = frappe.db.count("SIO Quiz Attempt", {"quiz": q.name})
    frappe.response["message"] = out
