# SIO lib totals: totals for one collection, optionally one unit.
# Args: collection, unit. Result: frappe.flags.sio_totals
collection = frappe.form_dict.get("collection")
unit = frappe.form_dict.get("unit")
units = [u for u in (frappe.form_dict.get("units") or "").split("|") if u]
cond = "collection = %(collection)s"
if unit:
    cond = cond + " and unit = %(unit)s"
if units:
    cond = cond + " and unit in %(units)s"
r = frappe.db.sql(
    """select
        coalesce(sum(case when entry_type != 'Items' then offered_amount end), 0),
        coalesce(sum(case when entry_type != 'Items' then paid_amount end), 0),
        coalesce(sum(case when entry_type != 'Items' then balance_amount end), 0),
        coalesce(sum(case when entry_type = 'Items' then items_value end), 0),
        count(*)
    from `tabSIO Collection Entry` where """ + cond,
    {"collection": collection, "unit": unit, "units": tuple(units or ["__none__"])})[0]
frappe.flags.sio_totals = {
    "offered": frappe.utils.flt(r[0]),
    "collected": frappe.utils.flt(r[1]),
    "balance": frappe.utils.flt(r[2]),
    "items": frappe.utils.flt(r[3]),
    "entries": frappe.utils.cint(r[4]),
}
