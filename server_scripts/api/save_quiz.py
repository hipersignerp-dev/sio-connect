# Add or change a weekly quiz (leaders). questions: JSON list of {question, options[2..4], correct (index),
# explanation}. A quiz that people have already taken can't have its questions changed.
if not ctx["caps"]["manage_events"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
doc = frappe.get_doc("SIO Quiz", name) if name else frappe.get_doc({"doctype": "SIO Quiz"})
title = (args.get("title") or "").strip()
if not title or not args.get("starts_on") or not args.get("ends_on"):
    frappe.throw(_("Enter the title and the dates."))
doc.title = title
doc.starts_on = args.get("starts_on")
doc.ends_on = args.get("ends_on")
doc.prize = (args.get("prize") or "").strip() or None
if SCOPE_UNITS is not None:
    doc.area = ctx["area"]
qs = json.loads(args.get("questions") or "[]") or []
taken = name and frappe.db.exists("SIO Quiz Attempt", {"quiz": name})
if qs and not taken:
    doc.set("questions", [])
    for q in qs:
        opts = [o.strip() for o in (q.get("options") or []) if (o or "").strip()]
        if not (q.get("question") or "").strip() or len(opts) < 2:
            frappe.throw(_("Each question needs the question and at least two options."))
        c = frappe.utils.cint(q.get("correct"))
        if c < 0 or c >= len(opts):
            frappe.throw(_("Mark the right answer for every question."))
        row = {"question": q.get("question").strip(), "correct": "ABCD"[c], "explanation": q.get("explanation") or None}
        for i in range(len(opts[:4])):
            row["option_" + "abcd"[i]] = opts[i]
        doc.append("questions", row)
if not doc.get("questions"):
    frappe.throw(_("Add at least one question."))
if not name and ctx["member"]:
    doc.created_by_member = ctx["member"].name
if name:
    doc.save(ignore_permissions=True)
else:
    doc.insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name, "locked": bool(taken)}
