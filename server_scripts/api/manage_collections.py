# Every collection, open and closed, with what came in. Finance and area admins.
if not ctx["caps"]["manage_collections"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
rows = frappe.get_all("SIO Collection",
                      fields=["name", "collection_type", "is_active", "unit", "target_amount", "starts_on", "ends_on"],
                      order_by="is_active desc, creation desc")
sums = {}
for r in frappe.db.sql("""select collection, count(name) as entries, coalesce(sum(paid_amount), 0) as collected
        from `tabSIO Collection Entry` group by collection""", as_dict=True):
    sums[r.collection] = r
for r in rows:
    s = sums.get(r.name)
    r["entries"] = s.entries if s else 0
    r["collected"] = frappe.utils.flt(s.collected) if s else 0
frappe.response["message"] = rows
