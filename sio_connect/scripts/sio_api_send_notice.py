ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

if not ctx["caps"]["send_notice"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
audience = args.get("audience") or "Unit"
if audience in ("Everyone", "Role") and not (ctx["is_admin"] or ctx["is_area_lead"]):
    frappe.throw(_("Only area leaders can send to everyone or by role."), frappe.PermissionError)
unit = None
if audience == "Unit":
    unit = args.get("unit") or ctx["unit"]
    if not unit:
        frappe.throw(_("Pick the unit to send this to."))
    if not in_scope(unit):
        frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
if not (args.get("title") or "").strip() or not (args.get("message") or "").strip():
    frappe.throw(_("Add a title and a message."))
doc = frappe.get_doc({
    "doctype": "SIO Notice",
    "title": args.get("title").strip(),
    "message": args.get("message").strip(),
    "audience": audience,
    "unit": unit,
    # area leaders' "everyone" means everyone in their area
    "area": ctx["area"] if (audience in ("Everyone", "Role") and SCOPE_UNITS is not None) else None,
    "member_role": args.get("member_role") if audience == "Role" else None,
    "event": args.get("event") if audience == "Event Registrants" else None,
    "send_whatsapp": frappe.utils.cint(args.get("send_whatsapp")),
    "send_email": frappe.utils.cint(args.get("send_email")),
}).insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name, "recipients": doc.recipient_count}
