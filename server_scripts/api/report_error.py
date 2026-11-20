# App errors sent automatically by the app (so problems are seen before students give up). Stored as SIO Feedback
# with kind "App error". The same error from the same person is kept once a day; at most 20 a day per person.
err = (args.get("error") or "").strip()[:300]
if not err:
    frappe.response["message"] = {"ok": 0}
else:
    today = frappe.utils.nowdate()
    me = frappe.session.user
    summary = ("App error: " + err.replace("\n", " "))[:140]
    dup = frappe.db.exists("SIO Feedback", {"user": me, "kind": "App error", "summary": summary, "creation": [">=", today]})
    many = frappe.db.count("SIO Feedback", {"user": me, "kind": "App error", "creation": [">=", today]}) >= 20
    if dup or many:
        frappe.response["message"] = {"ok": 1, "skipped": 1}
    else:
        m = ctx["member"]
        body = err + "\n\n" + (args.get("stack") or "")[:2600]
        frappe.get_doc({"doctype": "SIO Feedback", "kind": "App error", "status": "New", "summary": summary,
                        "message": body, "member": m.name if m else None, "unit": m.unit if m else None,
                        "user": me, "app_build": (args.get("app_build") or "")[:100],
                        "device": (args.get("device") or "")[:140]}).insert(ignore_permissions=True)
        frappe.response["message"] = {"ok": 1}
