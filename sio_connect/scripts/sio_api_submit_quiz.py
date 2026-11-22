ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

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
