# present: JSON list of member IDs who came
# @include meeting
if not ctx["caps"]["mark_attendance"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
doc = frappe.get_doc("SIO Meeting", args.get("name"))
if not can_manage_meeting(doc):
    frappe.throw(_("You can't mark attendance for this meeting."), frappe.PermissionError)
present = args.get("present") or "[]"
if isinstance(present, str):
    present = json.loads(present)
present = set(present)
existing = {}
for r in doc.attendance:
    existing[r.member] = {"status": r.status, "rsvp": r.rsvp}
if is_area_meeting(doc):
    roster = [m.name for m in area_invitees(doc.area, doc.get("invite"))]
else:
    roster = frappe.get_all("SIO Member", filters={"unit": doc.unit, "status": "Active"}, pluck="name")
members = list(roster) + [m for m in existing if m not in roster]
doc.set("attendance", [])
for m in members:
    old = existing.get(m)
    if m in present:
        status = "Present"
    elif old and old["status"] == "Excused":
        status = "Excused"
    else:
        status = "Absent"
    doc.append("attendance", {"member": m, "status": status, "rsvp": (old["rsvp"] if old else "") or ""})
if args.get("minutes") is not None:
    doc.minutes = args.get("minutes")
if frappe.utils.cint(args.get("complete") if args.get("complete") is not None else 1):
    doc.status = "Completed"
doc.save(ignore_permissions=True)
frappe.response["message"] = {"present": doc.present_count, "total": doc.total_count}
