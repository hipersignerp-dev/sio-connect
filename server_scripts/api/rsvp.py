if not ctx["caps"]["rsvp"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
doc = frappe.get_doc("SIO Meeting", args.get("name"))
if doc.unit != ctx["unit"]:
    frappe.throw(_("This meeting is for another unit."), frappe.PermissionError)
value = "Attending" if frappe.utils.cint(args.get("attending")) else "Not Attending"
found = False
for r in doc.attendance:
    if r.member == ctx["member"].name:
        r.rsvp = value
        found = True
if not found:
    doc.append("attendance", {"member": ctx["member"].name, "status": "Absent", "rsvp": value})
doc.save(ignore_permissions=True)
frappe.response["message"] = {"rsvp": value}
