# SIO lib events: events this person can see. 
# Args: upcoming_only (0/1), limit. Result: frappe.flags.sio_events
ctx = run_script("SIO lib ctx").sio_ctx
upcoming_only = frappe.utils.cint(frappe.form_dict.get("upcoming_only"))
limit = frappe.utils.cint(frappe.form_dict.get("limit")) or 50

conds = ["e.status != 'Cancelled'"]
if upcoming_only:
    conds.append("e.starts_on >= %(now)s and e.status in ('Registrations Open', 'Planning')")
else:
    conds.append("(e.starts_on >= %(since)s or e.status != 'Completed')")
if ctx["units"] is not None:
    # area-wide events of my area, and events of the units I may see
    conds.append("((ifnull(e.unit, '') = '' and (ifnull(e.area, '') = '' or e.area = %(area)s)) or e.unit in %(units)s)")
if not ctx["is_member"]:
    conds.append("e.open_to = 'Everyone'")

params = {
    "now": frappe.utils.now_datetime(),
    "since": frappe.utils.add_days(frappe.utils.nowdate(), -60),
    "unit": ctx["unit"] or "__none__",
    "area": ctx["area"] or "__none__",
    "units": tuple(ctx["units"] or ["__none__"]),
    "member": ctx["member"].name if ctx["member"] else "__none__",
}
rows = frappe.db.sql(
    """select e.name, e.title, e.event_type, e.starts_on, e.ends_on, e.venue, e.status, e.capacity,
        e.registered_count, e.budget, e.spent, e.unit, e.open_to,
        (select r.status from `tabSIO Event Registration` r where r.event = e.name and r.member = %(member)s
         and r.status != 'Cancelled' limit 1) as my_registration
    from `tabSIO Event` e where """ + " and ".join(conds) + """
    order by (e.status = 'Completed'), e.starts_on asc limit """ + str(limit),
    params, as_dict=True)
if not ctx["is_unit_admin"]:
    for r in rows:
        r.pop("budget", None)
        r.pop("spent", None)
frappe.flags.sio_events = rows  # caller: run_script("SIO lib events").sio_events
