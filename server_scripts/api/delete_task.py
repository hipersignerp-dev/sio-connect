# Remove an event task (organisers and the coordinator).
# @include tasks
doc = frappe.get_doc("SIO Event Task", args.get("name"))
if not can_run_tasks(task_event(doc.event)):
    frappe.throw(_("Only the organisers of this event can do this."), frappe.PermissionError)
frappe.delete_doc("SIO Event Task", doc.name, ignore_permissions=True)
frappe.response["message"] = {"deleted": doc.name}
