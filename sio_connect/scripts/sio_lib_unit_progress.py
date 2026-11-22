# SIO lib unit_progress: each unit's progress in one collection against its target.
# Args: collection. Result: frappe.flags.sio_unit_progress (list, largest target first)
collection = frappe.form_dict.get("collection")
targets = {}
for t in frappe.get_all("SIO Collection Unit Target", filters={"parent": collection, "parenttype": "SIO Collection"},
                        fields=["unit", "target"]):
    targets[t.unit] = frappe.utils.flt(t.target)
sums = {}
for r in frappe.db.sql(
        """select unit,
            coalesce(sum(case when entry_type != 'Items' then offered_amount end), 0) as offered,
            coalesce(sum(case when entry_type != 'Items' then paid_amount end), 0) as collected,
            coalesce(sum(case when entry_type != 'Items' then balance_amount end), 0) as balance,
            coalesce(sum(case when entry_type = 'Items' then items_value end), 0) as items,
            count(*) as entries
        from `tabSIO Collection Entry` where collection = %s and ifnull(unit, '') != '' group by unit""",
        collection, as_dict=True):
    sums[r.unit] = r
rows = []
for unit in list(targets.keys()) + [u for u in sums if u not in targets]:
    s = sums.get(unit) or {}
    target = targets.get(unit, 0)
    collected = frappe.utils.flt(s.get("collected"))
    rows.append({
        "unit": unit,
        "target": target,
        "offered": frappe.utils.flt(s.get("offered")),
        "collected": collected,
        "balance": frappe.utils.flt(s.get("balance")),
        "items": frappe.utils.flt(s.get("items")),
        "entries": frappe.utils.cint(s.get("entries")),
        "pct": round(100.0 * collected / target) if target else None,
        "to_target": max(target - collected, 0) if target else None,
    })
rows = sorted(rows, key=lambda r: (-r["target"], r["unit"]))
frappe.flags.sio_unit_progress = rows
