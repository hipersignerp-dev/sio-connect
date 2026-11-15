# Accounts: money in / out / balance. Args: from_date, to_date, unit, collection, event.
if not ctx["caps"]["view_accounts"]:
    frappe.throw(_("You are not allowed to see accounts."), frappe.PermissionError)
frappe.response["message"] = run_script(
    "SIO lib accounts", from_date=args.get("from_date") or "", to_date=args.get("to_date") or "",
    unit=args.get("unit") or "", collection=args.get("collection") or "", event=args.get("event") or "").sio_accounts
