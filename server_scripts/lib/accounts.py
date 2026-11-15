# SIO lib accounts: money in (collection payments received) and out (expenses paid) with opening balance,
# running balance and summaries. Unit admins only ever see their own unit.
# Args: from_date, to_date, unit, collection, event. Result: frappe.flags.sio_accounts
#   collection: that fund's money in, and expenses marked "Paid From" that fund
#   event: only that event's expenses (events have no money in)
ctx = run_script("SIO lib ctx").sio_ctx
f = frappe.form_dict
today = frappe.utils.getdate(frappe.utils.nowdate())
from_date = frappe.utils.getdate(f.get("from_date") or frappe.utils.get_first_day(today))
to_date = frappe.utils.getdate(f.get("to_date") or today)
unit = f.get("unit") or None
if not ctx["caps"]["all_units"]:
    unit = ctx["unit"] or "__none__"
collection = f.get("collection") or None
event = f.get("event") or None

in_cond = ["1=1"]
# Programme funds the area releases to a unit: for the area (no unit picked) they are money out, and the unit's
# spending from them is not counted again. For a unit they are money in, and its spending is money out.
out_cond = ["x.status = 'Paid'"]
if not unit:
    out_cond.append("ifnull(x.fund_request, '') = ''")
fr_cond = ["f.status in ('Released', 'Closed')"]
params = {"from": from_date, "to": to_date, "unit": unit, "collection": collection, "event": event}
if unit:
    in_cond.append("e.unit = %(unit)s")
    out_cond.append("x.unit = %(unit)s")
    fr_cond.append("f.unit = %(unit)s")
if collection:
    in_cond.append("e.collection = %(collection)s")
    out_cond.append("x.paid_from = %(collection)s")
    fr_cond.append("f.paid_from = %(collection)s")
if event:
    in_cond.append("1=0")
    out_cond.append("x.event = %(event)s")
    fr_cond.append("f.event = %(event)s")
in_where = " and ".join(in_cond)
out_where = " and ".join(out_cond)
fr_where = " and ".join(fr_cond)

def total_in(date_cond):
    return frappe.utils.flt(frappe.db.sql(
        """select coalesce(sum(p.amount), 0) from `tabSIO Collection Payment` p
        join `tabSIO Collection Entry` e on e.name = p.parent and p.parenttype = 'SIO Collection Entry'
        where """ + in_where + " and " + date_cond, params)[0][0])

def total_out(date_cond):
    return frappe.utils.flt(frappe.db.sql(
        "select coalesce(sum(x.amount), 0) from `tabSIO Expense Claim` x where " + out_where + " and " + date_cond,
        params)[0][0])

def total_fr(date_cond):
    return frappe.utils.flt(frappe.db.sql(
        "select coalesce(sum(f.released_amount), 0) from `tabSIO Fund Request` f where " + fr_where + " and "
        + date_cond, params)[0][0])

fr_sign = 1 if unit else -1
opening = total_in("p.payment_date < %(from)s") - total_out("x.paid_on < %(from)s") \
    + fr_sign * total_fr("f.released_on < %(from)s")

ins = frappe.db.sql(
    """select p.payment_date as date, p.amount, p.mode, p.reference_no, e.name as ref, e.contributor_name as party,
        e.collection, e.unit, e.entry_type
    from `tabSIO Collection Payment` p
    join `tabSIO Collection Entry` e on e.name = p.parent and p.parenttype = 'SIO Collection Entry'
    where """ + in_where + """ and p.payment_date between %(from)s and %(to)s
    order by p.payment_date, e.name""", params, as_dict=True)
outs = frappe.db.sql(
    """select x.paid_on as date, x.amount, x.payment_mode as mode, x.name as ref, x.description, x.category,
        x.claimed_by_name as party, x.event, x.unit, x.paid_from
    from `tabSIO Expense Claim` x
    where """ + out_where + """ and x.paid_on between %(from)s and %(to)s
    order by x.paid_on, x.name""", params, as_dict=True)

frs = frappe.db.sql(
    """select f.released_on as date, f.released_amount as amount, f.payment_mode as mode, f.name as ref, f.title,
        f.unit, f.event, f.paid_from
    from `tabSIO Fund Request` f
    where """ + fr_where + """ and f.released_on between %(from)s and %(to)s
    order by f.released_on, f.name""", params, as_dict=True)

rows = []
for r in frs:
    rows.append({"date": r.date, "type": "In" if unit else "Out", "amount": frappe.utils.flt(r.amount),
                 "title": "Programme fund: " + (r.title or ""),
                 "party": "From the area" if unit else (r.unit or "") + " unit", "unit": r.unit,
                 "collection": r.paid_from, "event": r.event, "category": "Programme fund", "mode": r.mode,
                 "ref": r.ref, "doctype": "SIO Fund Request"})
for r in ins:
    rows.append({"date": r.date, "type": "In", "amount": frappe.utils.flt(r.amount), "title": r.collection,
                 "party": r.party, "unit": r.unit, "collection": r.collection, "event": None, "category": None,
                 "mode": r.mode, "ref": r.ref, "doctype": "SIO Collection Entry"})
for r in outs:
    rows.append({"date": r.date, "type": "Out", "amount": frappe.utils.flt(r.amount), "title": r.description,
                 "party": r.party, "unit": r.unit, "collection": r.paid_from, "event": r.event,
                 "category": r.category, "mode": r.mode, "ref": r.ref, "doctype": "SIO Expense Claim"})
rows = sorted(rows, key=lambda r: (str(r["date"]), 0 if r["type"] == "In" else 1, r["ref"]))
balance = opening
total_in_amt = 0
total_out_amt = 0
in_by_collection = {}
out_by_category = {}
out_by_event = {}
for r in rows:
    if r["type"] == "In":
        balance += r["amount"]
        total_in_amt += r["amount"]
        k = r["collection"] or "Other"
        if r["doctype"] == "SIO Fund Request":
            k = "Programme funds from the area"
        in_by_collection[k] = in_by_collection.get(k, 0) + r["amount"]
    else:
        balance -= r["amount"]
        total_out_amt += r["amount"]
        k = r["category"] or "Other"
        out_by_category[k] = out_by_category.get(k, 0) + r["amount"]
        k = r["event"] or "Not for an event"
        out_by_event[k] = out_by_event.get(k, 0) + r["amount"]
    r["balance"] = balance

to_pay = frappe.utils.flt(frappe.db.sql(
    "select coalesce(sum(x.amount), 0) from `tabSIO Expense Claim` x where "
    + out_where.replace("x.status = 'Paid'", "x.status = 'Approved'"), params)[0][0]) \
    + (0 if unit else frappe.utils.flt(frappe.db.sql(
        "select coalesce(sum(f.approved_amount), 0) from `tabSIO Fund Request` f where "
        + fr_where.replace("f.status in ('Released', 'Closed')", "f.status = 'Approved'"), params)[0][0]))

def as_list(d):
    return sorted([{"name": k, "amount": d[k]} for k in d], key=lambda x: -x["amount"])

frappe.flags.sio_accounts = {
    "from_date": from_date,
    "to_date": to_date,
    "unit": None if unit == "__none__" else unit,
    "collection": collection,
    "event": event,
    "opening": opening,
    "in": total_in_amt,
    "out": total_out_amt,
    "closing": balance,
    "to_pay": to_pay,
    "rows": rows,
    "in_by_collection": as_list(in_by_collection),
    "out_by_category": as_list(out_by_category),
    "out_by_event": as_list(out_by_event),
}
