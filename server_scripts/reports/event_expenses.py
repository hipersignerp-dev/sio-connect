# Report "SIO Event Expenses": budget against spending for each event. Unit admins see their unit's spending.
ctx = run_script("SIO lib ctx").sio_ctx
cond = ["1=1"]
params = {}
if filters.get("from_date"):
    cond.append("date(e.starts_on) >= %(from)s")
    params["from"] = filters.get("from_date")
if filters.get("to_date"):
    cond.append("date(e.starts_on) <= %(to)s")
    params["to"] = filters.get("to_date")
xunit = ""
if not ctx["caps"]["all_units"]:
    xunit = " and x.unit = %(unit)s"
    params["unit"] = ctx["unit"] or "__none__"
elif filters.get("unit"):
    xunit = " and x.unit = %(unit)s"
    params["unit"] = filters.get("unit")
rows = frappe.db.sql(
    """select e.name as event, e.title, date(e.starts_on) as date, e.status, e.budget,
        coalesce(sum(case when x.status = 'Paid' then x.amount end), 0) as paid,
        coalesce(sum(case when x.status = 'Approved' then x.amount end), 0) as approved,
        coalesce(sum(case when x.status = 'Pending' then x.amount end), 0) as pending,
        count(x.name) as claims
    from `tabSIO Event` e
    left join `tabSIO Expense Claim` x on x.event = e.name""" + xunit + """
    where """ + " and ".join(cond) + """
    group by e.name, e.title, e.starts_on, e.status, e.budget
    order by e.starts_on desc""", params, as_dict=True)
for r in rows:
    r["spent"] = frappe.utils.flt(r.paid) + frappe.utils.flt(r.approved)
    r["remaining"] = frappe.utils.flt(r.budget) - r["spent"] if r.budget else None
    r["used_pct"] = round(100.0 * r["spent"] / frappe.utils.flt(r.budget)) if r.budget else None
columns = [
    {"fieldname": "event", "label": "Event", "fieldtype": "Link", "options": "SIO Event", "width": 110},
    {"fieldname": "title", "label": "Title", "fieldtype": "Data", "width": 220},
    {"fieldname": "date", "label": "Date", "fieldtype": "Date", "width": 100},
    {"fieldname": "status", "label": "Status", "fieldtype": "Data", "width": 130},
    {"fieldname": "budget", "label": "Budget", "fieldtype": "Currency", "width": 120},
    {"fieldname": "paid", "label": "Paid", "fieldtype": "Currency", "width": 110},
    {"fieldname": "approved", "label": "Approved, To Pay", "fieldtype": "Currency", "width": 130},
    {"fieldname": "pending", "label": "Waiting Approval", "fieldtype": "Currency", "width": 130},
    {"fieldname": "spent", "label": "Spent", "fieldtype": "Currency", "width": 110},
    {"fieldname": "remaining", "label": "Left in Budget", "fieldtype": "Currency", "width": 120},
    {"fieldname": "used_pct", "label": "% Used", "fieldtype": "Percent", "width": 80},
    {"fieldname": "claims", "label": "Claims", "fieldtype": "Int", "width": 70},
]
summary = [
    {"label": "Budget", "value": sum([frappe.utils.flt(r.budget) for r in rows]), "datatype": "Currency", "indicator": "Blue"},
    {"label": "Spent", "value": sum([r["spent"] for r in rows]), "datatype": "Currency", "indicator": "Red"},
    {"label": "Waiting Approval", "value": sum([frappe.utils.flt(r.pending) for r in rows]), "datatype": "Currency",
     "indicator": "Orange"},
]
data = [columns, rows, None, None, summary]
