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
