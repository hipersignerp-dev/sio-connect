ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# One collection with its unit targets (for the add / edit screen), and every unit with its active members,
# so the target can be split by members. Without a name: just the units. Finance and area admins.
if not ctx["caps"]["manage_collections"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
units = frappe.db.sql(
    """select u.name as unit, count(m.name) as members
    from `tabSIO Unit` u
    left join `tabSIO Member` m on m.unit = u.name and m.status = 'Active'
    where u.active = 1
    group by u.name order by u.name""", as_dict=True)
units = [u for u in units if in_scope(u.unit)]
out = {"units": units, "collection": None, "entries": 0}
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Collection", name)
    out["collection"] = {
        "name": doc.name, "collection_name": doc.collection_name, "collection_type": doc.collection_type,
        "is_active": doc.is_active, "unit": doc.unit, "target_amount": doc.target_amount,
        "starts_on": doc.starts_on, "ends_on": doc.ends_on, "description": doc.description,
        "unit_targets": [{"unit": r.unit, "target": r.target} for r in doc.unit_targets],
    }
    out["entries"] = frappe.db.count("SIO Collection Entry", {"collection": name})
frappe.response["message"] = out
