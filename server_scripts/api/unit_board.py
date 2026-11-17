# Unit challenge board for my area: attendance, daily readers and quiz scores, unit against unit.
m = ctx["member"]
area = ctx["area"]
if not area and m:
    area = frappe.db.get_value("SIO Unit", m.unit, "district") if m.unit else None
units = frappe.get_all("SIO Unit", filters={"active": 1, "district": area} if area else {"active": 1}, pluck="name")
since30 = frappe.utils.add_days(frappe.utils.nowdate(), -30)
since7 = frappe.utils.add_days(frappe.utils.nowdate(), -6)
board = []
for u in units:
    members = frappe.db.count("SIO Member", {"unit": u, "status": "Active"})
    att = frappe.db.sql(
        """select count(*), sum(a.status = 'Present') from `tabSIO Meeting Attendance` a
        join `tabSIO Meeting` mt on mt.name = a.parent
        where mt.unit = %s and mt.status = 'Completed' and mt.meeting_date >= %s""", (u, since30))[0]
    readers = frappe.db.sql(
        """select count(distinct d.member) from `tabSIO Streak Day` d join `tabSIO Member` x on x.name = d.member
        where x.unit = %s and d.activity = 'Reading' and d.day >= %s""", (u, since7))[0][0]
    quiz = frappe.db.sql(
        """select avg(score / nullif(total, 0)) * 100, count(*) from `tabSIO Quiz Attempt`
        where unit = %s and creation >= %s""", (u, since30))[0]
    att_pct = round(100.0 * frappe.utils.flt(att[1]) / att[0]) if att[0] else 0
    read_pct = round(100.0 * readers / members) if members else 0
    quiz_pct = round(frappe.utils.flt(quiz[0])) if quiz[1] else 0
    board.append({"unit": u, "members": members, "attendance": att_pct, "readers": readers, "readers_pct": read_pct,
                  "quiz": quiz_pct, "quiz_takers": quiz[1], "score": round((att_pct + read_pct + quiz_pct) / 3.0),
                  "mine": bool(m) and m.unit == u})
board = sorted(board, key=lambda x: -x["score"])
frappe.response["message"] = {"area": area, "units": board}
