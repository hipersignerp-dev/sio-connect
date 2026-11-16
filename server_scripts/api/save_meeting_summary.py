# Save the meeting summary (minutes). Stored as plain text for the app and as formatted minutes for the desk.
# Saving a summary marks a scheduled meeting as completed.
if not ctx["caps"]["schedule_meeting"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
doc = frappe.get_doc("SIO Meeting", args.get("name"))
if ctx["scope"] and doc.unit != ctx["scope"]:
    frappe.throw(_("This meeting is for another unit."), frappe.PermissionError)
text = (args.get("summary") or "").strip()
doc.summary = text or None
doc.minutes = frappe.utils.md_to_html(text) if text else None
if text and doc.status == "Scheduled":
    doc.status = "Completed"
doc.save(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name, "summary": doc.summary, "status": doc.status}
