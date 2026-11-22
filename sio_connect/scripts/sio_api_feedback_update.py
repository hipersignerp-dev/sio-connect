ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Admin: mark a report Seen / Done and optionally reply. The person gets a notice with the reply (e.g. "Fixed in
# the next update, thank you!").
if not ctx["caps"].get("handle_feedback"):
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
d = frappe.get_doc("SIO Feedback", args.get("name"))
st = args.get("status")
if st in ("New", "Seen", "Done"):
    d.status = st
reply = (args.get("reply") or "").strip()
if reply:
    d.reply = reply[:1000]
    d.replied_on = frappe.utils.now_datetime()
d.save(ignore_permissions=True)
if (reply or st == "Done") and d.member and d.kind != "App error":
    title = "Your report: fixed ✅" if st == "Done" else "Reply to your report"
    frappe.get_doc({"doctype": "SIO Notice", "title": title,
                    "message": (reply or "Thank you! We fixed the problem you reported.") + "\n\nYou wrote: " + (d.summary or ""),
                    "audience": "Person", "member": d.member}).insert(ignore_permissions=True)
frappe.response["message"] = {"ok": 1, "status": d.status}
