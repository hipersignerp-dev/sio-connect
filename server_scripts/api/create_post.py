# Post an achievement on my page (kind Badge / Streak / Quiz / Note) with a short caption. Friends see it.
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
kind = args.get("kind") if args.get("kind") in ("Badge", "Streak", "Quiz", "Note") else "Note"
title = (args.get("title") or "").strip()[:140]
body = (args.get("body") or "").strip()[:500]
if not title:
    frappe.throw(_("Write something."))
recent = frappe.db.count("SIO Post", {"member": m.name, "creation": [">", frappe.utils.add_to_date(
    frappe.utils.now_datetime(), minutes=-10)]})
if recent >= 5:
    frappe.throw(_("Slow down a little: try again in a few minutes."))
p = frappe.get_doc({"doctype": "SIO Post", "member": m.name, "unit": m.unit, "kind": kind,
                    "badge": (args.get("badge") or "")[:40] or None, "title": title, "body": body or None,
                    "cheers": 0}).insert(ignore_permissions=True)
frappe.response["message"] = {"name": p.name}
