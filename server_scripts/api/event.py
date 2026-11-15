found = [e for e in run_script("SIO lib events", limit=500).sio_events if e.name == args.get("name")]
if not found:
    frappe.throw(_("Event not found."), frappe.DoesNotExistError)
out = found[0]
out["description"] = frappe.db.get_value("SIO Event", out.name, "description")
frappe.response["message"] = out
