ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Programme fund requests from units to the area. Unit admins see their unit's; finance / area admins all.
caps = ctx["caps"]
if not (caps["request_funds"] or caps["approve_funds"] or caps["view_accounts"]):
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
filters = {}
if SCOPE_UNITS is not None:
    filters["unit"] = ["in", scope_list()]
if args.get("status"):
    filters["status"] = args.get("status")
rows = frappe.get_all("SIO Fund Request", filters=filters,
                      fields=["name", "title", "unit", "event", "needed_by", "status", "requested_by_name",
                              "amount_requested", "approved_amount", "released_amount", "spent_amount", "purpose",
                              "breakdown", "remarks", "released_on", "payment_mode", "paid_from", "creation"],
                      order_by="creation desc", limit=200)
totals = {}
for r in rows:
    totals[r.status] = totals.get(r.status, 0) + 1
    r["balance"] = frappe.utils.flt(r.released_amount) - frappe.utils.flt(r.spent_amount)
funds = [c.name for c in frappe.get_all("SIO Collection", filters={"is_active": 1}, fields=["name"])] \
    if caps["approve_funds"] else []
frappe.response["message"] = {"requests": rows, "counts": totals, "can_approve": caps["approve_funds"],
                              "can_request": caps["request_funds"], "funds": funds}
