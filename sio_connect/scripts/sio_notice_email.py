# SIO Notice, After Insert: email the members when asked. (WhatsApp: connect your provider here.)
if doc.send_email:
    filters = {"status": ["in", ["Active", "Pending Approval"]], "email": ["is", "set"]}
    if doc.audience == "Unit":
        filters["unit"] = doc.unit
    elif doc.audience == "Role":
        filters["member_role"] = doc.member_role
    if doc.audience in ("Everyone", "Role") and doc.get("area"):
        filters["area"] = doc.area
    elif doc.audience == "Event Registrants":
        regs = frappe.get_all("SIO Event Registration", filters={"event": doc.event, "status": ["!=", "Cancelled"]},
                              pluck="member")
        filters["name"] = ["in", regs or ["__none__"]]
    emails = frappe.get_all("SIO Member", filters=filters, pluck="email")
    if emails:
        frappe.sendmail(recipients=[], bcc=emails, subject=doc.title, message=doc.message, delayed=True)
