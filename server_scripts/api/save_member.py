# Add a student / member directly (no sign-up needed), or change their details. Unit admins: their own unit,
# Associate or Member roles. If the student later signs up in the app with the same mobile, the sign-up joins
# this record.
if not ctx["caps"]["add_members"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Member", name)
    if ctx["scope"] and doc.unit != ctx["scope"]:
        frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
else:
    doc = frappe.get_doc({"doctype": "SIO Member", "status": "Active", "member_role": "Associate"})
full_name = (args.get("full_name") or "").strip()
mobile = "".join([c for c in (args.get("mobile") or "") if c.isdigit() or c == "+"])
if len(full_name) < 3:
    frappe.throw(_("Enter the full name."))
if len([c for c in mobile if c.isdigit()]) < 10:
    frappe.throw(_("Enter a valid mobile number."))
unit = args.get("unit") or doc.unit or ctx["unit"]
if ctx["scope"]:
    unit = ctx["scope"]
role = args.get("member_role") or doc.member_role or "Associate"
if not ctx["is_admin"] and role != doc.member_role and role not in ("Associate", "Worker"):
    frappe.throw(_("Only area admins can give that role."), frappe.PermissionError)
doc.full_name = full_name
doc.mobile = mobile
doc.email = (args.get("email") or "").strip().lower() or None
doc.unit = unit
doc.member_role = role
if args.get("status") in ("Active", "Inactive"):
    doc.status = args.get("status")
for f in ("campus", "course", "home_town"):
    doc.set(f, args.get(f) or None)
doc.year_of_study = args.get("year_of_study") or ""
# path to membership
if args.get("mulakath_done") is not None:
    doc.mulakath_done = frappe.utils.cint(args.get("mulakath_done"))
    doc.mulakath_on = (args.get("mulakath_on") or doc.mulakath_on or frappe.utils.nowdate()) if doc.mulakath_done else None
if args.get("books_read") is not None:
    doc.books_read = (args.get("books_read") or "").strip() or None
if args.get("membership_note") is not None:
    doc.membership_note = (args.get("membership_note") or "").strip() or None
if name:
    doc.save(ignore_permissions=True)
else:
    doc.insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name, "status": doc.status}
