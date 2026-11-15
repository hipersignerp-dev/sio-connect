# SIO lib collections: open collections (Ramadan Collection, Baithul Mal, ...) this person can see,
# each with totals for their scope and their own offers. Result: frappe.flags.sio_collections
ctx = run_script("SIO lib ctx").sio_ctx
caps = ctx["caps"]
member = ctx["member"]
filters = {"is_active": 1}
rows = frappe.get_all("SIO Collection", filters=filters,
                      fields=["name", "collection_type", "target_amount", "starts_on", "ends_on", "description", "unit"],
                      order_by="creation desc")
out = []
for c in rows:
    if c.unit and not caps["all_units"] and c.unit != ctx["unit"]:
        continue
    item = {"name": c.name, "collection_type": c.collection_type, "target": frappe.utils.flt(c.target_amount),
            "starts_on": c.starts_on, "ends_on": c.ends_on, "description": c.description, "unit": c.unit,
            "totals": None, "my_offered": 0, "my_paid": 0}
    if caps["view_collection_totals"]:
        item["totals"] = run_script("SIO lib totals", collection=c.name, unit=ctx["scope"] or "").sio_totals
    elif caps["collect"] and member:
        t = frappe.db.sql(
            """select coalesce(sum(case when entry_type != 'Items' then offered_amount end), 0),
                coalesce(sum(paid_amount), 0), coalesce(sum(balance_amount), 0),
                coalesce(sum(case when entry_type = 'Items' then items_value end), 0), count(*)
            from `tabSIO Collection Entry` where collection = %s and collected_by = %s""", (c.name, member.name))[0]
        item["totals"] = {"offered": frappe.utils.flt(t[0]), "collected": frappe.utils.flt(t[1]),
                          "balance": frappe.utils.flt(t[2]), "items": frappe.utils.flt(t[3]),
                          "entries": frappe.utils.cint(t[4]), "scope": "collected_by_me"}
    if member:
        mine = frappe.db.sql(
            """select coalesce(sum(offered_amount), 0), coalesce(sum(paid_amount), 0) from `tabSIO Collection Entry`
            where collection = %s and contributor_member = %s""", (c.name, member.name))[0]
        item["my_offered"] = frappe.utils.flt(mine[0])
        item["my_paid"] = frappe.utils.flt(mine[1])
    out.append(item)
frappe.flags.sio_collections = out
