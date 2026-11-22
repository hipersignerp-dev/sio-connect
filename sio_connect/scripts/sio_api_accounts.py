ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Accounts: money in / out / balance. Args: from_date, to_date, unit, collection, event.
if not ctx["caps"]["view_accounts"]:
    frappe.throw(_("You are not allowed to see accounts."), frappe.PermissionError)
frappe.response["message"] = run_script(
    "SIO lib accounts", from_date=args.get("from_date") or "", to_date=args.get("to_date") or "",
    unit=args.get("unit") or "", collection=args.get("collection") or "", event=args.get("event") or "").sio_accounts
