# Send a follow-up reminder for one task now (organisers and the coordinator).
# @include tasks
doc = frappe.get_doc("SIO Event Task", args.get("name"))
ev = task_event(doc.event)
if not can_run_tasks(ev):
    frappe.throw(_("Only the organisers of this event can do this."), frappe.PermissionError)
if not doc.assigned_to:
    frappe.throw(_("This task is not assigned to anyone yet."))
notify_person(doc.assigned_to, "Reminder: " + doc.title,
              "For " + ev.title + (". Due " + when_text(doc.due_on) if doc.due_on else "")
              + ". Please update the task in SIO Connect when it's done.", event=ev.name, task=doc.name)
frappe.db.set_value("SIO Event Task", doc.name, "last_reminded", frappe.utils.nowdate())
frappe.response["message"] = {"reminded": doc.assigned_name}
