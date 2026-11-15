caps = ctx["caps"]
member = ctx["member"]
notices = run_script("SIO lib notices", limit=3).sio_notices
out = {"me": ctx["me"], "next_meeting": None, "next_event": None, "notices": notices}

if ctx["unit"]:
    rows = frappe.get_all(
        "SIO Meeting",
        filters={"unit": ctx["unit"], "status": "Scheduled", "meeting_date": [">=", frappe.utils.nowdate()]},
        fields=["name", "topic", "meeting_type", "meeting_date", "meeting_time", "venue", "unit"],
        order_by="meeting_date asc, meeting_time asc", limit=1)
    if rows:
        mt = rows[0]
        mt["my_rsvp"] = None
        if member:
            mt["my_rsvp"] = frappe.db.get_value(
                "SIO Meeting Attendance", {"parent": mt.name, "parenttype": "SIO Meeting", "member": member.name}, "rsvp")
        out["next_meeting"] = mt
    if member:
        att = frappe.db.sql(
            """select count(*), sum(a.status = 'Present') from `tabSIO Meeting Attendance` a
            join `tabSIO Meeting` m on m.name = a.parent
            where a.member = %s and m.status = 'Completed' and m.meeting_date >= %s""",
            (member.name, frappe.utils.add_days(frappe.utils.nowdate(), -180)))[0]
        out["my_attendance"] = {"total": frappe.utils.cint(att[0]), "present": frappe.utils.cint(att[1])}

events = run_script("SIO lib events", upcoming_only=1, limit=1).sio_events
if events:
    out["next_event"] = events[0]

collections = run_script("SIO lib collections").sio_collections
out["collections"] = [{"name": c["name"], "collection_type": c["collection_type"], "totals": c["totals"]}
                      for c in collections]
out["my_offers"] = {"offered": sum([c["my_offered"] for c in collections]),
                    "paid": sum([c["my_paid"] for c in collections])}
if caps["view_members"]:
    base = {}
    if ctx["scope"]:
        base["unit"] = ctx["scope"]
    active_f = dict(base)
    active_f["status"] = "Active"
    pending_f = dict(base)
    pending_f["status"] = "Pending Approval"
    out["members"] = {"active": frappe.db.count("SIO Member", active_f),
                      "pending": frappe.db.count("SIO Member", pending_f)}
if caps["approve_expense"]:
    if ctx["is_finance"]:
        pend = frappe.db.sql(
            "select count(*), coalesce(sum(amount), 0) from `tabSIO Expense Claim` where status = 'Pending'")[0]
    else:
        pend = frappe.db.sql(
            """select count(*), coalesce(sum(amount), 0) from `tabSIO Expense Claim`
            where status = 'Pending' and unit in %(u)s""", {"u": ctx["approver_units"]})[0]
    out["pending_expenses"] = {"count": frappe.utils.cint(pend[0]), "amount": frappe.utils.flt(pend[1])}
if caps["approve_funds"]:
    out["pending_funds"] = frappe.db.count("SIO Fund Request", {"status": "Pending"})
frappe.response["message"] = out
