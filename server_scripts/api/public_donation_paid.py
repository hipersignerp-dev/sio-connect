# After paying in their UPI app, the visitor gives the UPI reference so finance can match and confirm it.
f = frappe.form_dict
ref = (f.get("ref") or "").strip()
mobile = "".join([c for c in (f.get("mobile") or "") if c.isdigit()])
utr = (f.get("payment_ref") or "").strip()[:60]
if len(mobile) < 10:
    frappe.throw(_("Donation not found."))
row = frappe.db.get_value("SIO Collection Entry", ref, ["contributor_mobile", "status", "collection"], as_dict=True)
public = frappe.db.get_value("SIO Settings", "SIO Settings", "public_collection")
if not row or row.collection != public or "".join([c for c in (row.contributor_mobile or "") if c.isdigit()])[-10:] != mobile[-10:]:
    frappe.throw(_("Donation not found."))
if not utr:
    frappe.throw(_("Enter the UPI reference (UTR) from your payment app."))
frappe.db.set_value("SIO Collection Entry", ref, "payment_ref", utr)
frappe.response["message"] = {"ref": ref, "status": "Waiting for SIO to confirm"}
