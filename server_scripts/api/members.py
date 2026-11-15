if not ctx["caps"]["view_members"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
filters = {}
if ctx["scope"]:
    filters["unit"] = ctx["scope"]
if args.get("status"):
    filters["status"] = args.get("status")
or_filters = None
q = (args.get("q") or "").strip()
if q:
    like = "%" + q + "%"
    or_filters = {"full_name": ["like", like], "mobile": ["like", like], "name": ["like", like]}
rows = frappe.get_all("SIO Member", filters=filters, or_filters=or_filters,
                      fields=["name", "full_name", "mobile", "email", "member_role", "status", "unit", "campus",
                              "course", "year_of_study", "joined_on", "creation"],
                      order_by="full_name asc", limit=300)
pending = [r for r in rows if r.status == "Pending Approval"]
others = [r for r in rows if r.status != "Pending Approval"]
frappe.response["message"] = pending + others
