ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Bug reports and feedback for the people who look after the app (SIO admins). Filter by status (New / Seen /
# Done) and kind; app errors are counted but grouped, so one bug from many phones shows once.
if not ctx["caps"].get("handle_feedback"):
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
st = args.get("status") or "New"
filters = {"status": st} if st in ("New", "Seen", "Done") else {}
kind = args.get("kind") or ""
if kind in ("Problem", "Idea", "Other", "App error"):
    filters["kind"] = kind
rows = frappe.get_all("SIO Feedback", filters=filters,
                      fields=["name", "kind", "status", "summary", "message", "member", "unit", "user", "app_build",
                              "device", "screen", "screenshot", "reply", "replied_on", "creation"],
                      order_by="creation desc", limit=200)
for r in rows:
    r["full_name"] = frappe.db.get_value("SIO Member", r.member, "full_name") if r.member else r.user
counts = {}
for s in ("New", "Seen", "Done"):
    counts[s] = frappe.db.count("SIO Feedback", {"status": s})
frappe.response["message"] = {"rows": rows, "counts": counts}
