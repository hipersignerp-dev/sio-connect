# present: JSON list of member IDs who came
if not ctx["caps"]["mark_attendance"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
doc = frappe.get_doc("SIO Meeting", args.get("name"))
if ctx["scope"] and doc.unit != ctx["scope"]:
    frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
present = args.get("present") or "[]"
if isinstance(present, str):
    present = json.loads(present)
present = set(present)
existing = {}
for r in doc.attendance:
    existing[r.member] = {"status": r.status, "rsvp": r.rsvp}
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
