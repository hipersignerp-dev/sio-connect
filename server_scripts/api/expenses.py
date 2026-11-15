caps = ctx["caps"]
if not (caps["claim_expense"] or caps["approve_expense"]):
    frappe.throw(_("You are not allowed to see expenses."), frappe.PermissionError)
filters = {}
if args.get("status"):
    filters["status"] = args.get("status")
if caps["approve_expense"]:
    pass
elif ctx["is_unit_admin"]:
    filters["unit"] = ctx["unit"] or "__none__"
else:
    filters["claimed_by"] = ctx["member"].name
rows = frappe.get_all("SIO Expense Claim", filters=filters,
                      fields=["name", "description", "category", "amount", "expense_date", "status", "claimed_by",
                              "claimed_by_name", "unit", "event", "bill", "remarks"],
                      order_by="creation desc", limit=200)
totals = {}
for r in rows:
    totals[r.status] = totals.get(r.status, 0) + frappe.utils.flt(r.amount)
frappe.response["message"] = {"claims": rows, "totals": totals, "can_approve": caps["approve_expense"]}
