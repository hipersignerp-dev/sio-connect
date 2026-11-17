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
