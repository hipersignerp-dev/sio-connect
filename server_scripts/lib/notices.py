# SIO lib notices: updates this person should see. 
# Args: limit. Result: frappe.flags.sio_notices
ctx = run_script("SIO lib ctx").sio_ctx
limit = frappe.utils.cint(frappe.form_dict.get("limit")) or 50
m = ctx["member"]
units = ctx["units"]
params = {
    "unit": ctx["unit"] or "__none__",
    "units": tuple(units or ["__none__"]),
    "area": ctx["area"] or "__none__",
    "all": 1 if units is None else 0,
    "role": m.member_role if m else "__none__",
    "member": m.name if m else "__none__",
    "user": ctx["user"],
}
frappe.flags.sio_notices = frappe.db.sql(
    """select n.name, n.title, n.message, n.audience, n.unit, n.member_role, n.event, n.sent_on,
        n.recipient_count, n.sent_by
    from `tabSIO Notice` n
    where (n.audience = 'Everyone' and (%(all)s = 1 or ifnull(n.area, '') = '' or n.area = %(area)s))
        or (n.audience = 'Unit' and (n.unit = %(unit)s or n.unit in %(units)s))
        or (n.audience = 'Role' and n.member_role = %(role)s and (%(all)s = 1 or ifnull(n.area, '') = ''
            or n.area = %(area)s))
        or (n.audience = 'Event Registrants' and exists (select 1 from `tabSIO Event Registration` r
            where r.event = n.event and r.member = %(member)s and r.status != 'Cancelled'))
        or n.sent_by = %(user)s
    order by n.sent_on desc limit """ + str(limit),
    params, as_dict=True)
