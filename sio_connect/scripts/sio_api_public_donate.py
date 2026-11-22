# A visitor donates: record it in the public donations fund, then hand back what the app needs to open UPI.
f = frappe.form_dict
st = frappe.db.get_value("SIO Settings", "SIO Settings",
                         ["upi_id", "upi_payee_name", "min_donation", "public_collection"], as_dict=True) or {}
if not (st.get("upi_id") and st.get("public_collection")):
    frappe.throw(_("Online donation is not set up yet. Please contact SIO."))
name = (f.get("full_name") or "").strip()
mobile = "".join([c for c in (f.get("mobile") or "") if c.isdigit() or c == "+"])
amount = frappe.utils.flt(f.get("amount"))
if len(name) < 2:
    frappe.throw(_("Enter your name."))
if len([c for c in mobile if c.isdigit()]) < 10:
    frappe.throw(_("Enter a valid mobile number."))
if amount < (frappe.utils.flt(st.get("min_donation")) or 10) or amount > 500000:
    frappe.throw(_("Enter an amount between") + " " + str(frappe.utils.cint(st.get("min_donation") or 10)) + " "
                 + _("and 5,00,000."))
doc = frappe.get_doc({
    "doctype": "SIO Collection Entry",
    "collection": st.get("public_collection"),
    "entry_type": "Offer",
    "contributor_name": name[:140],
    "contributor_type": "Well-wisher",
    "contributor_mobile": mobile,
    "contributor_place": (f.get("place") or "").strip()[:140] or None,
    "offered_amount": amount,
}).insert(ignore_permissions=True)
frappe.response["message"] = {"ref": doc.name, "upi_id": st.get("upi_id"), "payee": st.get("upi_payee_name") or "SIO",
                              "amount": amount, "note": "SIO donation " + doc.name}
