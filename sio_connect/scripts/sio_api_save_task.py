ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Add or change an event task (title, responsibility, assigned_to, due_on, notes, status). Organisers and the
# coordinator can do everything; the person the task is assigned to can update its status and notes.
# The assignee is told about a new task (and about a task moved to them).
# --- event task helpers (shared) ---
def task_event(ev_name):
    ev = frappe.db.get_value("SIO Event", ev_name, ["name", "title", "unit", "area", "starts_on", "venue", "status"],
                             as_dict=True)
    if not ev:
        frappe.throw(_("Event not found."), frappe.DoesNotExistError)
    return ev


def can_manage_event(ev):
    # office bearers of the event's unit (or, for an area-wide event, the area leaders / admins)
    if not ctx["caps"]["manage_events"]:
        return False
    if ev.unit:
        return in_scope(ev.unit)
    return SCOPE_UNITS is None or (ctx["is_area_lead"] and ev.area == ctx["area"])


def is_coordinator(ev_name):
    if not ctx["member"]:
        return False
    return bool(frappe.db.exists("SIO Event Team Member", {"parent": ev_name, "parenttype": "SIO Event",
                                                           "member": ctx["member"].name,
                                                           "responsibility": ["like", "%oordinator%"]}))


def can_run_tasks(ev):
    return can_manage_event(ev) or is_coordinator(ev.name)


def notify_person(member, title, message, event=None, task=None):
    if not member:
        return
    frappe.get_doc({"doctype": "SIO Notice", "title": title, "message": message, "audience": "Person",
                    "member": member, "event": event, "task": task}).insert(ignore_permissions=True)


def when_text(dt):
    return frappe.utils.format_datetime(dt, "EEE d MMM, h:mm a") if dt else ""
# --- end event task helpers ---
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
