if not ctx["caps"]["send_notice"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
audience = args.get("audience") or "Unit"
if audience in ("Everyone", "Role") and not ctx["is_admin"]:
    frappe.throw(_("Only area admins can send to everyone or by role."), frappe.PermissionError)
unit = None
if audience == "Unit":
    unit = args.get("unit") or ctx["unit"]
    if ctx["scope"] and unit != ctx["scope"]:
        frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
if not (args.get("title") or "").strip() or not (args.get("message") or "").strip():
    frappe.throw(_("Add a title and a message."))
doc = frappe.get_doc({
    "doctype": "SIO Notice",
    "title": args.get("title").strip(),
    "message": args.get("message").strip(),
    "audience": audience,
    "unit": unit,
    "member_role": args.get("member_role") if audience == "Role" else None,
    "event": args.get("event") if audience == "Event Registrants" else None,
    "send_whatsapp": frappe.utils.cint(args.get("send_whatsapp")),
    "send_email": frappe.utils.cint(args.get("send_email")),
}).insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name, "recipients": doc.recipient_count}
