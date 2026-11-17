# SIO Member, Before Save: clean mobile, no duplicate mobiles, joining date, who approved.
doc.mobile = (doc.mobile or "").replace(" ", "") or None
if doc.mobile:
    dup = frappe.db.get_value("SIO Member", {"mobile": doc.mobile, "name": ["!=", doc.name or ""]})
    if dup:
        frappe.throw(_("This mobile number is already registered") + " (" + dup + ").")
elif doc.member_role not in ("Area Admin", "Area President", "Area Secretary"):
    frappe.throw(_("Enter a mobile number."))
if doc.status == "Active" and not doc.joined_on:
    doc.joined_on = frappe.utils.today()
if not doc.is_new() and doc.has_value_changed("status") and doc.status == "Active" and not doc.approved_by:
    doc.approved_by = frappe.session.user
    doc.approved_on = frappe.utils.now_datetime()
# Area: taken from the unit; area presidents / secretaries (no unit) must have one.
if doc.unit:
    doc.area = frappe.db.get_value("SIO Unit", doc.unit, "district") or doc.get("area")
elif doc.member_role in ("Area President", "Area Secretary") and not doc.get("area"):
    frappe.throw(_("Pick the area for an area president or secretary."))
elif doc.member_role in ("Unit President", "Unit Secretary") and not doc.unit:
    frappe.throw(_("Pick the unit for a unit president or secretary."))
