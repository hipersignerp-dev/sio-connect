# Add or change a unit. Area admins only. A unit's name can't be changed once added.
if not ctx["caps"]["manage_units"]:
    frappe.throw(_("Only area admins can add or change units."), frappe.PermissionError)
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Unit", name)
else:
    uname = (args.get("unit_name") or "").strip()
    if len(uname) < 2:
        frappe.throw(_("Enter the unit name."))
    if frappe.db.exists("SIO Unit", uname):
        frappe.throw(_("A unit with this name already exists."))
    doc = frappe.get_doc({"doctype": "SIO Unit", "unit_name": uname})
doc.district = (args.get("district") or "").strip() or None
doc.area = (args.get("area") or "").strip() or None
doc.active = 0 if str(args.get("active")) in ("0", "false", "False") else 1
for f in ("president", "secretary"):
    v = args.get(f) or None
    if v and frappe.db.get_value("SIO Member", v, "unit") != doc.name and name:
        frappe.throw(_("The president and secretary must be members of this unit."))
    doc.set(f, v)
if name:
    doc.save(ignore_permissions=True)
else:
    doc.insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name}
