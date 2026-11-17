# Answer a quiz once (answers: JSON list of option indexes). Returns the score with the right answers.
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
q = frappe.get_doc("SIO Quiz", args.get("name"))
today = frappe.utils.nowdate()
if str(q.starts_on) > today or str(q.ends_on) < today:
    frappe.throw(_("This quiz is closed."))
if frappe.db.exists("SIO Quiz Attempt", {"quiz": q.name, "member": m.name}):
    frappe.throw(_("You have already taken this quiz."))
answers = json.loads(args.get("answers") or "[]")
score = 0
for i in range(len(q.questions)):
    right = "ABCD".index(q.questions[i].correct)
    if i < len(answers) and answers[i] is not None and frappe.utils.cint(answers[i]) == right:
        score = score + 1
frappe.get_doc({"doctype": "SIO Quiz Attempt", "quiz": q.name, "member": m.name, "unit": m.unit, "score": score,
                "total": len(q.questions), "answers": json.dumps(answers)}).insert(ignore_permissions=True)
if not frappe.db.exists("SIO Streak Day", {"member": m.name, "activity": "Quiz", "day": today}):
    frappe.get_doc({"doctype": "SIO Streak Day", "member": m.name, "activity": "Quiz", "day": today}).insert(
        ignore_permissions=True)
frappe.response["message"] = {"score": score, "total": len(q.questions)}
