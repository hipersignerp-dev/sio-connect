# Add or change a collection (Ramadan Collection, Baithul Mal, ...) and its unit targets.
if not ctx["caps"]["manage_collections"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
if name:
    doc = frappe.get_doc("SIO Collection", name)
else:
    cname = (args.get("collection_name") or "").strip()
    if len(cname) < 3:
        frappe.throw(_("Enter a name for the collection, e.g. Ramadan Collection 1448."))
    if frappe.db.exists("SIO Collection", cname):
        frappe.throw(_("A collection with this name already exists."))
    doc = frappe.get_doc({"doctype": "SIO Collection", "collection_name": cname})
doc.collection_type = args.get("collection_type") or doc.collection_type or "Other"
doc.unit = args.get("unit") or None
doc.starts_on = args.get("starts_on") or None
doc.ends_on = args.get("ends_on") or None
doc.description = args.get("description") or None
doc.target_amount = frappe.utils.flt(args.get("target_amount"))
doc.is_active = 0 if str(args.get("is_active")) in ("0", "false", "False") else 1
targets = json.loads(args.get("unit_targets") or "[]") or []
doc.set("unit_targets", [])
for t in targets:
    amt = frappe.utils.flt(t.get("target"))
    if t.get("unit") and amt > 0:
        doc.append("unit_targets", {"unit": t.get("unit"), "target": amt})
if name:
    doc.save(ignore_permissions=True)
else:
    doc.insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name, "target_amount": doc.target_amount,
                              "unit_targets_total": doc.unit_targets_total}
