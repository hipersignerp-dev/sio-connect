ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# The team of an event: who coordinates, who does media, stage, food ... (team: JSON list of
# {member, responsibility}). Office bearers and the event's coordinator can change it. New people are told.
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
ev = task_event(args.get("event"))
if not can_run_tasks(ev):
    frappe.throw(_("Only the organisers of this event can change its team."), frappe.PermissionError)
team = json.loads(args.get("team") or "[]") or []
doc = frappe.get_doc("SIO Event", ev.name)
before = [r.member for r in doc.get("team") or []]
doc.set("team", [])
seen = []
for t in team:
    m = t.get("member")
    resp = (t.get("responsibility") or "").strip() or "Volunteer"
    if not m or not frappe.db.exists("SIO Member", m) or (m + resp) in seen:
        continue
    seen.append(m + resp)
    doc.append("team", {"member": m, "responsibility": resp})
doc.save(ignore_permissions=True)
for r in doc.team:
    if r.member not in before:
        notify_person(r.member, "You're on the team: " + ev.title,
                      "Responsibility: " + r.responsibility + ". " + when_text(ev.starts_on)
                      + (" · " + ev.venue if ev.venue else "") + ". Open the event in SIO Connect to see your tasks.",
                      event=ev.name)
frappe.response["message"] = {"team": [{"member": r.member, "member_name": r.member_name,
                                        "responsibility": r.responsibility} for r in doc.team]}
