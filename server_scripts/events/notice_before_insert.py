# SIO Notice, Before Insert: sender, time and how many members it reaches.
doc.sent_on = frappe.utils.now_datetime()
doc.sent_by = frappe.session.user
filters = {"status": ["in", ["Active", "Pending Approval"]]}
if doc.audience == "Unit":
    filters["unit"] = doc.unit
elif doc.audience == "Role":
    filters["member_role"] = doc.member_role
if doc.audience in ("Everyone", "Role") and doc.get("area"):
    filters["area"] = doc.area
elif doc.audience == "Person":
    filters["name"] = doc.member or "__none__"
elif doc.audience == "Event Registrants":
    regs = frappe.get_all("SIO Event Registration", filters={"event": doc.event, "status": ["!=", "Cancelled"]},
                          pluck="member")
    filters["name"] = ["in", regs or ["__none__"]]
doc.recipient_count = frappe.db.count("SIO Member", filters)
