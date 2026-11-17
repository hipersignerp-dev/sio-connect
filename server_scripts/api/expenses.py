caps = ctx["caps"]
if not (caps["claim_expense"] or caps["approve_expense"]):
    frappe.throw(_("You are not allowed to see expenses."), frappe.PermissionError)
# finance / area admins: every claim. A unit's expense approver: that unit's claims and their own.
# Unit president / secretary: their unit. Members: their own claims.
filters = {}
or_filters = None
if args.get("status"):
    filters["status"] = args.get("status")
me_name = ctx["member"].name if ctx["member"] else "__none__"
# units whose claims this person may approve: area presidents / secretaries their area's units
act_units = list(set((SCOPE_UNITS or []) if ctx["is_area_lead"] else []) | set(ctx["approver_units"]))
if ctx["is_finance"]:
    pass
elif act_units:
    or_filters = {"unit": ["in", act_units], "claimed_by": me_name}
elif ctx["is_unit_admin"]:
    filters["unit"] = ctx["unit"] or "__none__"
else:
    filters["claimed_by"] = me_name
rows = frappe.get_all("SIO Expense Claim", filters=filters, or_filters=or_filters,
                      fields=["name", "description", "category", "amount", "expense_date", "status", "claimed_by",
                              "claimed_by_name", "unit", "event", "paid_from", "fund_request", "bill", "remarks"],
                      order_by="creation desc", limit=200)
totals = {}
for r in rows:
    totals[r.status] = totals.get(r.status, 0) + frappe.utils.flt(r.amount)
    # who may approve this one: finance, or the unit's approver for someone else's claim
    r["can_act"] = ctx["is_finance"] or (r.unit in act_units and r.claimed_by != me_name)
funds = [c.name for c in frappe.get_all("SIO Collection", filters={"is_active": 1}, fields=["name"])] \
    if ctx["is_finance"] else []
# released programme funds this person's unit can claim against
fr_filters = {"status": "Released"}
if SCOPE_UNITS is not None:
    fr_filters["unit"] = ["in", scope_list()]
fund_requests = frappe.get_all("SIO Fund Request", filters=fr_filters,
                               fields=["name", "title", "unit", "event", "released_amount", "spent_amount"],
                               order_by="creation desc", limit=50)
frappe.response["message"] = {"claims": rows, "totals": totals, "can_approve": caps["approve_expense"], "funds": funds,
                              "fund_requests": fund_requests, "approver_units": ctx["approver_units"]}
