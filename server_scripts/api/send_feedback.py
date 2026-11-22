# Feedback from the app (Settings > Send feedback): a problem, an idea or anything else. Saved as SIO Feedback for
# the area team, with the app build and phone model to help fix problems. At most 10 a day per person.
msg = (args.get("message") or "").strip()
if not msg:
    frappe.throw(_("Please write something."))
if len(msg) > 3000:
    msg = msg[:3000]
today = frappe.utils.nowdate()
if frappe.db.count("SIO Feedback", {"user": frappe.session.user, "creation": [">=", today]}) >= 10:
    frappe.throw(_("Thanks! You've sent a lot today. Please try again tomorrow."))
kind = args.get("kind") if args.get("kind") in ["Problem", "Idea", "Other"] else "Other"
m = ctx["member"]
summary = msg.replace("\n", " ")
if len(summary) > 80:
    summary = summary[:77] + "..."
doc = frappe.get_doc({"doctype": "SIO Feedback", "kind": kind, "status": "New", "summary": summary, "message": msg,
                      "member": m.name if m else None, "unit": m.unit if m else None, "user": frappe.session.user,
                      "app_build": (args.get("app_build") or "")[:100], "device": (args.get("device") or "")[:140]})
doc.screen = (args.get("screen") or "")[:140]
doc.insert(ignore_permissions=True)
shot = args.get("screenshot")
if shot and len(shot) < 3000000:
    f = frappe.get_doc({"doctype": "File", "file_name": "bug-" + frappe.utils.generate_hash(length=12) + ".png",
                        "attached_to_doctype": "SIO Feedback", "attached_to_name": doc.name, "is_private": 1,
                        "content": shot, "decode": True}).insert(ignore_permissions=True)
    frappe.db.set_value("SIO Feedback", doc.name, "screenshot", f.file_url)
frappe.response["message"] = {"ok": 1, "name": doc.name}
