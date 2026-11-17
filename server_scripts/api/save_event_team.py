# The team of an event: who coordinates, who does media, stage, food ... (team: JSON list of
# {member, responsibility}). Office bearers and the event's coordinator can change it. New people are told.
# @include tasks
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
