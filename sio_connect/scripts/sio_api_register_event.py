ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

if not ctx["caps"]["register_events"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
member = ctx["member"]
ev = frappe.get_doc("SIO Event", args.get("event"))
if ev.open_to == "Members Only" and not ctx["is_member"]:
    frappe.throw(_("This event is for members only."))
existing = frappe.db.get_value("SIO Event Registration",
                               {"event": ev.name, "member": member.name, "status": ["!=", "Cancelled"]})
if frappe.utils.cint(args.get("cancel")):
    if existing:
        reg = frappe.get_doc("SIO Event Registration", existing)
        reg.status = "Cancelled"
        reg.save(ignore_permissions=True)
    frappe.response["message"] = {"registered": False}
elif existing:
    frappe.response["message"] = {"registered": True}
else:
    if ev.status in ("Completed", "Cancelled"):
        frappe.throw(_("Registrations are not open for this event."))
    if ev.capacity and frappe.utils.cint(ev.registered_count) >= ev.capacity:
        frappe.throw(_("Sorry, this event is full."))
    frappe.get_doc({"doctype": "SIO Event Registration", "event": ev.name, "member": member.name}).insert(
        ignore_permissions=True)
    frappe.response["message"] = {"registered": True}
