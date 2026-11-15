if not ctx["member"]:
    frappe.throw(_("No member record for this account."))
m = frappe.get_doc("SIO Member", ctx["member"].name)
for field in ("campus", "course", "home_town", "year_of_study"):
    if args.get(field) is not None:
        m.set(field, args.get(field))
if args.get("unit") and m.status == "Pending Approval":
    m.unit = args.get("unit")
m.save(ignore_permissions=True)
frappe.response["message"] = run_script("SIO lib ctx").sio_ctx["me"]
