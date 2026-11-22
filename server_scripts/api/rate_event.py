# Rate a programme I attended (1-5 stars, optional comment). Leaders see the average and comments.
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
ev = args.get("event")
if not frappe.db.exists("SIO Event Registration", {"event": ev, "member": m.name, "status": "Attended"}):
    frappe.throw(_("Only people who attended can rate this programme."))
r = frappe.utils.cint(args.get("rating"))
if r < 1 or r > 5:
    frappe.throw(_("Choose 1 to 5 stars."))
c = (args.get("comment") or "").strip()[:500]
old = frappe.db.get_value("SIO Event Feedback", {"event": ev, "member": m.name}, "name")
if old:
    frappe.db.set_value("SIO Event Feedback", old, {"rating": r, "comment": c})
else:
    frappe.get_doc({"doctype": "SIO Event Feedback", "event": ev, "member": m.name, "rating": r,
                    "comment": c}).insert(ignore_permissions=True)
frappe.response["message"] = {"ok": 1}
