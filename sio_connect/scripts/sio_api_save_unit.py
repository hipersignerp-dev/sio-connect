ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Add or change a unit. Area admins only. A unit's name can't be changed once added.
if not ctx["caps"]["manage_units"]:
    frappe.throw(_("Only area leaders can add or change units."), frappe.PermissionError)
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Unit", name)
    if not in_scope(doc.name):
        frappe.throw(_("That unit is not in your area."), frappe.PermissionError)
else:
    uname = (args.get("unit_name") or "").strip()
    if len(uname) < 2:
        frappe.throw(_("Enter the unit name."))
    if frappe.db.exists("SIO Unit", uname):
        frappe.throw(_("A unit with this name already exists."))
    doc = frappe.get_doc({"doctype": "SIO Unit", "unit_name": uname})
doc.district = (args.get("district") or "").strip() or None
if SCOPE_UNITS is not None:
    doc.district = ctx["area"]  # area presidents / secretaries: units of their own area
doc.area = (args.get("area") or "").strip() or None
doc.active = 0 if str(args.get("active")) in ("0", "false", "False") else 1
for f in ("president", "secretary", "expense_approver"):
    v = args.get(f) or None
    if v and frappe.db.get_value("SIO Member", v, "unit") != doc.name and name:
        frappe.throw(_("The president, secretary and expense approver must be members of this unit."))
    doc.set(f, v)
if name:
    doc.save(ignore_permissions=True)
else:
    doc.insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name}
