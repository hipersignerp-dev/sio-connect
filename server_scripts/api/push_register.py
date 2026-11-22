# The phone registers its Firebase push token after sign-in (and when Firebase changes it). One row per token;
# a token moves to whoever signs in on that phone. "remove" unregisters it (sign out).
tok = (args.get("token") or "").strip()
if not tok or len(tok) > 4000:
    frappe.throw(_("Missing token."))
h = frappe.utils.sha256_hash(tok)
name = frappe.db.get_value("SIO Push Token", {"token_hash": h}, "name")
if frappe.utils.cint(args.get("remove")):
    if name:
        frappe.delete_doc("SIO Push Token", name, ignore_permissions=True)
    frappe.response["message"] = {"ok": 1}
else:
    m = ctx["member"]
    vals = {"member": m.name if m else None, "user": frappe.session.user, "platform": (args.get("platform") or "android")[:20],
            "last_seen": frappe.utils.now_datetime()}
    if name:
        frappe.db.set_value("SIO Push Token", name, vals)
    else:
        d = {"doctype": "SIO Push Token", "token": tok, "token_hash": h}
        d.update(vals)
        frappe.get_doc(d).insert(ignore_permissions=True)
    # push works once the server has the Firebase key and runs the sio_connect app (it does the sending)
    ready = bool(frappe.db.get_single_value("SIO Settings", "firebase_service_account")) and \
        bool(frappe.db.get_value("Installed Application", {"app_name": "sio_connect"}, "name"))
    frappe.response["message"] = {"ok": 1, "push": 1 if ready else 0}
