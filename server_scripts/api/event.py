# One event, with its expenses: office bearers see budget, spent, pending and every expense;
# members see their own claims for the event.
found = [e for e in run_script("SIO lib events", limit=500).sio_events if e.name == args.get("name")]
if not found:
    frappe.throw(_("Event not found."), frappe.DoesNotExistError)
out = found[0]
ev = frappe.db.get_value("SIO Event", out.name, ["description", "budget", "unit"], as_dict=True)
out["description"] = ev.description
filters = {"event": out.name}
see_all = ctx["caps"]["all_units"] or (ctx["is_unit_admin"] and ev.unit and ev.unit == ctx["unit"])
if see_all:
    pass
elif ctx["is_unit_admin"]:
    filters["unit"] = ctx["unit"] or "__none__"
elif ctx["member"]:
    filters["claimed_by"] = ctx["member"].name
else:
    filters["name"] = "__none__"
expenses = frappe.get_all("SIO Expense Claim", filters=filters,
                          fields=["name", "description", "category", "amount", "expense_date", "status",
                                  "claimed_by_name", "unit", "paid_on", "paid_from"],
                          order_by="expense_date desc, creation desc")
out["expenses"] = expenses
if ctx["is_unit_admin"] or ctx["is_finance"]:
    paid = 0
    approved = 0
    pending = 0
    by_category = {}
    for x in expenses:
        amt = frappe.utils.flt(x.amount)
        if x.status == "Paid":
            paid += amt
        elif x.status == "Approved":
            approved += amt
        elif x.status == "Pending":
            pending += amt
        if x.status in ("Paid", "Approved"):
            by_category[x.category or "Other"] = by_category.get(x.category or "Other", 0) + amt
    budget = frappe.utils.flt(ev.budget)
    out["expense_summary"] = {
        "budget": budget,
        "paid": paid,
        "approved": approved,
        "spent": paid + approved,
        "pending": pending,
        "remaining": budget - paid - approved if budget else None,
        "by_category": sorted([{"category": k, "amount": by_category[k]} for k in by_category],
                              key=lambda r: -r["amount"]),
        "scope": "all" if see_all else "my unit",
    }
frappe.response["message"] = out
