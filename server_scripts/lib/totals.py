# SIO lib totals: collection totals for a campaign, optionally one unit.
# Args: campaign, unit. Result: frappe.flags.sio_totals
campaign = frappe.form_dict.get("campaign")
unit = frappe.form_dict.get("unit")
cond = "campaign = %(campaign)s"
if unit:
    cond = cond + " and unit = %(unit)s"
r = frappe.db.sql(
    """select
        coalesce(sum(case when entry_type != 'In-kind' then pledged_amount end), 0),
        coalesce(sum(case when entry_type != 'In-kind' then paid_amount end), 0),
        coalesce(sum(case when entry_type != 'In-kind' then balance_amount end), 0),
        coalesce(sum(case when entry_type = 'In-kind' then in_kind_value end), 0),
        count(*)
    from `tabSIO Collection Entry` where """ + cond,
    {"campaign": campaign, "unit": unit})[0]
frappe.flags.sio_totals = {
    "pledged": frappe.utils.flt(r[0]),
    "collected": frappe.utils.flt(r[1]),
    "balance": frappe.utils.flt(r[2]),
    "in_kind": frappe.utils.flt(r[3]),
    "entries": frappe.utils.cint(r[4]),
}
