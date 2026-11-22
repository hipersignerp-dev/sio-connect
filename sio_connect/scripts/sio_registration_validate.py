# SIO Event Registration, Before Save: one registration per member per event.
if doc.status != "Cancelled":
    dup = frappe.db.get_value("SIO Event Registration", {"event": doc.event, "member": doc.member,
                              "name": ["!=", doc.name or ""], "status": ["!=", "Cancelled"]})
    if dup:
        frappe.throw(_("Already registered for this event."))
