# Add someone to the donor list before they give, or change their details (name, mobile, place, notes).
# Unit admins and collectors add for their own unit; finance and area admins for any unit.
if not ctx["caps"]["view_donors"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
member = ctx["member"]
if name:
    doc = frappe.get_doc("SIO Donor", name)
    if SCOPE_UNITS is not None:
        mine = in_scope(doc.unit) and (ctx["is_unit_admin"] or (member and doc.added_by == member.name))
        if not mine:
            frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
else:
    doc = frappe.get_doc({"doctype": "SIO Donor", "added_by": member.name if member else None})
dname = (args.get("donor_name") or "").strip()
if len(dname) < 2:
    frappe.throw(_("Enter the name."))
mobile = "".join([c for c in (args.get("mobile") or "") if c.isdigit() or c == "+"])
digits = "".join([c for c in mobile if c.isdigit()])
if mobile and len(digits) < 10:
    frappe.throw(_("Enter a valid mobile number."))
if digits:
    for d in frappe.get_all("SIO Donor", filters={"mobile": ["like", "%" + digits[-10:]], "name": ["!=", doc.name or ""]},
                            fields=["name", "donor_name", "unit"]):
        frappe.throw(_("This mobile is already in the donor list") + " (" + d.donor_name + ", " + (d.unit or "") + ").")
unit = args.get("unit") or doc.unit or ctx["unit"]
if not ctx["caps"]["all_units"]:
    unit = ctx["unit"]
if unit and not in_scope(unit):
    frappe.throw(_("That unit is not in your area."), frappe.PermissionError)
if not unit:
    frappe.throw(_("Pick the unit."))
doc.donor_name = dname
doc.mobile = mobile or None
doc.place = (args.get("place") or "").strip() or None
doc.donor_type = args.get("donor_type") or doc.donor_type or "Well-wisher"
doc.unit = unit
doc.notes = (args.get("notes") or "").strip() or None
if name:
    doc.save(ignore_permissions=True)
else:
    doc.insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name}
