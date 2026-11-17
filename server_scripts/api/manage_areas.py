# Areas with their units, member counts and office bearers. Area admins also see inactive areas.
show_all = ctx["is_admin"]
mine_only = SCOPE_UNITS is not None and ctx["is_area_lead"]
areas = frappe.db.sql(
    """select a.name, a.district, a.active, a.president, a.secretary,
        (select full_name from `tabSIO Member` where name = a.president) as president_name,
        (select full_name from `tabSIO Member` where name = a.secretary) as secretary_name
    from `tabSIO Area` a """ + ("" if show_all else "where a.active = 1 ") + """
    order by a.active desc, a.name""", as_dict=True)
units = frappe.db.sql(
    """select u.name, u.district as area, u.active,
        (select count(*) from `tabSIO Member` m where m.unit = u.name and m.status = 'Active') as members
    from `tabSIO Unit` u """ + ("" if show_all else "where u.active = 1 ") + """
    order by u.name""", as_dict=True)
if mine_only:
    areas = [a for a in areas if a.name == ctx["area"]]
for a in areas:
    mine = [u for u in units if u.area == a.name]
    a["units"] = mine
    a["unit_count"] = len([u for u in mine if u.active])
    a["members"] = sum([u.members for u in mine])
frappe.response["message"] = {"areas": areas, "can_add_area": ctx["is_admin"],
                              "no_area": [u for u in units if not u.area and u.active] if not mine_only else []}
