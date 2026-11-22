ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Every unit with its office bearers and member counts. Anyone signed in gets the list; area admins
# also get the inactive ones.
conds = []
if not (ctx["is_admin"]):
    conds.append("u.active = 1")
if SCOPE_UNITS is not None and ctx["is_area_lead"]:
    conds.append("u.district = " + frappe.db.escape(ctx["area"] or "__none__"))
rows = frappe.db.sql(
    """select u.name, u.district, u.area, u.active, u.president, u.secretary, u.expense_approver,
        (select full_name from `tabSIO Member` where name = u.expense_approver) as approver_name,
        (select full_name from `tabSIO Member` where name = u.president) as president_name,
        (select full_name from `tabSIO Member` where name = u.secretary) as secretary_name,
        (select count(*) from `tabSIO Member` m where m.unit = u.name and m.status = 'Active') as members,
        (select count(*) from `tabSIO Member` m where m.unit = u.name and m.status = 'Pending Approval') as pending
    from `tabSIO Unit` u
    """ + ((" where " + " and ".join(conds)) if conds else "") + """
    order by u.active desc, u.name""", as_dict=True)
frappe.response["message"] = rows
