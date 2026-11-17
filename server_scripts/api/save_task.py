# Add or change an event task (title, responsibility, assigned_to, due_on, notes, status). Organisers and the
# coordinator can do everything; the person the task is assigned to can update its status and notes.
# The assignee is told about a new task (and about a task moved to them).
# @include tasks
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Event Task", name)
    ev = task_event(doc.event)
else:
    ev = task_event(args.get("event"))
    doc = frappe.get_doc({"doctype": "SIO Event Task", "event": ev.name})
boss = can_run_tasks(ev)
mine = bool(name) and ctx["member"] and doc.assigned_to == ctx["member"].name
if not boss and not mine:
    frappe.throw(_("Only the organisers of this event can do this."), frappe.PermissionError)
old_assignee = doc.assigned_to
if boss:
    title = (args.get("title") or doc.title or "").strip()
    if not title:
        frappe.throw(_("Enter the task."))
    doc.title = title
    doc.responsibility = (args.get("responsibility") or "").strip() or None
    assigned = args.get("assigned_to") or None
    if assigned and not frappe.db.exists("SIO Member", assigned):
        frappe.throw(_("Pick the person from the list."))
    doc.assigned_to = assigned
    doc.due_on = args.get("due_on") or None
if args.get("notes") is not None:
    doc.notes = args.get("notes") or None
status = args.get("status")
if status in ("Open", "In Progress", "Done"):
    if status == "Done" and doc.status != "Done":
        doc.done_on = frappe.utils.now_datetime()
    if status != "Done":
        doc.done_on = None
    doc.status = status
if name:
    doc.save(ignore_permissions=True)
else:
    doc.insert(ignore_permissions=True)
if doc.assigned_to and doc.assigned_to != old_assignee and doc.status != "Done":
    notify_person(doc.assigned_to, "New task: " + doc.title,
                  "For " + ev.title + (". Due " + when_text(doc.due_on) if doc.due_on else "")
                  + ". Open My tasks in SIO Connect.", event=ev.name, task=doc.name)
frappe.response["message"] = {"name": doc.name, "status": doc.status}
