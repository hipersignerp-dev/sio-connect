# SIO Collection, Before Save: one target per unit, total of unit targets; an empty area target is filled
# from the unit targets.
seen = []
total = 0
for row in doc.unit_targets:
    if row.unit in seen:
        frappe.throw(_("Unit {0} is listed twice in Unit Targets.").replace("{0}", row.unit))
    seen.append(row.unit)
    total += frappe.utils.flt(row.target)
doc.unit_targets_total = total
if total and not frappe.utils.flt(doc.target_amount):
    doc.target_amount = total
