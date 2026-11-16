# SIO Member, Before Save: clean mobile, no duplicate mobiles, joining date, who approved.
doc.mobile = (doc.mobile or "").replace(" ", "") or None
if doc.mobile:
    dup = frappe.db.get_value("SIO Member", {"mobile": doc.mobile, "name": ["!=", doc.name or ""]})
    if dup:
        frappe.throw(_("This mobile number is already registered") + " (" + dup + ").")
elif doc.member_role != "Area Admin":
    frappe.throw(_("Enter a mobile number."))
if doc.status == "Active" and not doc.joined_on:
    doc.joined_on = frappe.utils.today()
if not doc.is_new() and doc.has_value_changed("status") and doc.status == "Active" and not doc.approved_by:
    doc.approved_by = frappe.session.user
    doc.approved_on = frappe.utils.now_datetime()
