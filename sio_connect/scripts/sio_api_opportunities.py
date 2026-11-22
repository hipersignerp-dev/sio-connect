ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# The student board: scholarships, exam & admission notices, careers, study circles, notes and blood
# requests for my area (and everywhere), open ones first, newest first.
kind = args.get("kind") or None
filters = {"status": "Open"}
if kind:
    filters["kind"] = kind
rows = frappe.get_all("SIO Opportunity", filters=filters,
                      fields=["name", "kind", "title", "details", "link", "attachment", "last_date", "place",
                              "blood_group", "contact", "area", "unit", "posted_by", "creation"],
                      order_by="creation desc", limit=300)
today = frappe.utils.nowdate()
me = ctx["member"].name if ctx["member"] else None
lead = bool(ctx["caps"]["send_notice"] or ctx["caps"]["manage_events"])
out = []
names = {}
for r in rows:
    if SCOPE_UNITS is not None and r.area and r.area != ctx["area"]:
        continue
    if r.last_date and str(r.last_date) < today and r.kind != "Notes":
        continue  # past its date
    if r.posted_by and r.posted_by not in names:
        names[r.posted_by] = frappe.db.get_value("SIO Member", r.posted_by, ["full_name", "photo"], as_dict=True)
    p = names.get(r.posted_by) or {}
    r["posted_by_name"] = p.get("full_name")
    r["posted_by_photo"] = p.get("photo")
    r["mine"] = bool(me) and r.posted_by == me
    r["can_delete"] = r["mine"] or (lead and (SCOPE_UNITS is None or r.area == ctx["area"]))
    out.append(r)
counts = {}
for r in out:
    counts[r.kind] = counts.get(r.kind, 0) + 1
frappe.response["message"] = {"items": out, "counts": counts, "can_post_all": lead}
