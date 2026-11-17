if not ctx["caps"]["view_members"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
filters = {}
if SCOPE_UNITS is not None:
    filters["unit"] = ["in", scope_list()]
if args.get("status"):
    filters["status"] = args.get("status")
if args.get("unit"):
    if not in_scope(args.get("unit")):
        frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
    filters["unit"] = args.get("unit")
if args.get("area"):
    filters["area"] = args.get("area")
if args.get("role"):
    filters["member_role"] = args.get("role")
or_filters = None
q = (args.get("q") or "").strip()
if q:
    like = "%" + q + "%"
    or_filters = {"full_name": ["like", like], "mobile": ["like", like], "name": ["like", like]}
rows = frappe.get_all("SIO Member", filters=filters, or_filters=or_filters,
                      fields=["name", "full_name", "photo", "mobile", "email", "member_role", "status", "unit", "area",
                              "campus", "course", "year_of_study", "joined_on", "creation", "home_town", "latitude",
                              "longitude", "location_note", "mulakath_done", "mulakath_on", "books_read",
                              "membership_note"],
                      order_by="full_name asc", limit=1000)
pending = [r for r in rows if r.status == "Pending Approval"]
others = [r for r in rows if r.status != "Pending Approval"]
people = pending + others
if frappe.utils.cint(args.get("with_facets")):
    conds = ["1=1"]
    params = {"units": tuple(scope_list()), "status": args.get("status") or ""}
    if SCOPE_UNITS is not None:
        conds.append("unit in %(units)s")
    if args.get("status"):
        conds.append("status = %(status)s")

    def facet(field):
        return [{"value": r[0], "count": r[1]} for r in frappe.db.sql(
            "select " + field + ", count(*) from `tabSIO Member` where " + " and ".join(conds) + " and ifnull(" + field
            + ", '') != '' group by " + field + " order by count(*) desc, " + field, params)]
    frappe.response["message"] = {"people": people, "total": len(people), "units": facet("unit"),
                                  "areas": facet("area"), "roles": facet("member_role"),
                                  "all": frappe.db.sql("select count(*) from `tabSIO Member` where " + " and ".join(conds), params)[0][0]}
else:
    frappe.response["message"] = people
