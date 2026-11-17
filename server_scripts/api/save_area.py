# Add or change an area. Area admins only. An area's name can't be changed once added.
if not ctx["is_admin"]:
    frappe.throw(_("Only area admins can add or change areas."), frappe.PermissionError)
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Area", name)
else:
    aname = (args.get("area_name") or "").strip()
    if len(aname) < 2:
        frappe.throw(_("Enter the area name."))
    if frappe.db.exists("SIO Area", aname):
        frappe.throw(_("An area with this name already exists."))
    doc = frappe.get_doc({"doctype": "SIO Area", "area_name": aname})
doc.district = (args.get("district") or "").strip() or None
doc.active = 0 if str(args.get("active")) in ("0", "false", "False") else 1
doc.president = args.get("president") or None
doc.secretary = args.get("secretary") or None
if name:
    doc.save(ignore_permissions=True)
else:
    doc.insert(ignore_permissions=True)
# units picked for this area move under it
if args.get("units") is not None:
    picked = json.loads(args.get("units") or "[]") or []
    for u in picked:
        frappe.db.set_value("SIO Unit", u, "district", doc.name)
    for u in frappe.get_all("SIO Unit", filters={"district": doc.name}, pluck="name"):
        if u not in picked:
            frappe.db.set_value("SIO Unit", u, "district", None)
frappe.response["message"] = {"name": doc.name}
