# SIO Event, After Insert: tell people about the new programme. A unit's event goes to that unit; an event for the
# whole area goes to everyone in that area (or everyone, when no area is set). It shows in Updates and as a
# notification on their phones.
if doc.status != "Cancelled":
    when = frappe.utils.format_datetime(doc.starts_on, "EEE d MMM, h:mm a") if doc.starts_on else ""
    bits = [b for b in [when, doc.venue] if b]
    frappe.get_doc({
        "doctype": "SIO Notice",
        "title": "New programme: " + doc.title,
        "message": (" · ".join(bits) + ". " if bits else "") + "Open SIO Connect to see the details and register.",
        "audience": "Unit" if doc.unit else "Everyone",
        "unit": doc.unit or None,
        "area": None if doc.unit else (doc.get("area") or None),
        "event": doc.name,
    }).insert(ignore_permissions=True)
