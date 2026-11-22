# SIO Meeting, Before Save: attendance counts.
doc.total_count = len(doc.attendance)
doc.present_count = len([r for r in doc.attendance if r.status == "Present"])
# A meeting is for a unit or (area meeting) for an area.
if not doc.unit and not doc.get("area"):
    frappe.throw("Set the unit, or the area for an area meeting.")
if doc.unit:
    doc.area = None
