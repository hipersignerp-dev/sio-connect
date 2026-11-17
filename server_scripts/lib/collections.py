# SIO lib collections: open collections (Ramadan Collection, Baithul Mal, ...) this person can see,
# each with totals for their scope and their own offers. Result: frappe.flags.sio_collections
ctx = run_script("SIO lib ctx").sio_ctx
caps = ctx["caps"]
member = ctx["member"]
filters = {"is_active": 1}
rows = frappe.get_all("SIO Collection", filters=filters,
                      fields=["name", "collection_type", "target_amount", "starts_on", "ends_on", "description", "unit",
                              "open_to"],
                      order_by="creation desc")
out = []
today = frappe.utils.getdate(frappe.utils.nowdate())
for c in rows:
    # Each collection runs for its own period (Ramadan collection, Baithul Mal year ...). Outside it, members don't
    # see it; leaders still see an ended one to follow up balances.
    phase = "Running"
    if c.starts_on and frappe.utils.getdate(c.starts_on) > today:
        phase = "Upcoming"
    elif c.ends_on and frappe.utils.getdate(c.ends_on) < today:
        phase = "Ended"
    if phase == "Ended" and not caps["view_collection_totals"]:
        continue
    if c.unit and ctx["units"] is not None and c.unit not in ctx["units"]:
        continue
    open_to = c.open_to or "Everyone"
    # Baithul Mal and the like are for workers and above, not associates
    if open_to == "Workers and above" and not ctx["is_member"]:
        continue
    # the public donations fund is handled by finance only
    if open_to == "Public donations" and ctx["units"] is not None:
        continue
    item = {"name": c.name, "collection_type": c.collection_type, "target": frappe.utils.flt(c.target_amount),
            "starts_on": c.starts_on, "ends_on": c.ends_on, "description": c.description, "unit": c.unit,
            "totals": None, "my_offered": 0, "my_paid": 0, "unit_target": None, "open_to": open_to, "phase": phase,
            "my_pledge": None}
    if ctx["unit"]:
        ut = frappe.db.get_value("SIO Collection Unit Target",
                                 {"parent": c.name, "parenttype": "SIO Collection", "unit": ctx["unit"]}, "target")
        item["unit_target"] = frappe.utils.flt(ut) if ut else None
    if caps["view_collection_totals"]:
        scope_units = ctx["units"]
        item["totals"] = run_script("SIO lib totals", collection=c.name,
                                    units="" if scope_units is None else "|".join(scope_units or ["__none__"])).sio_totals
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
        p = frappe.db.get_value("SIO Collection Entry",
                                {"collection": c.name, "contributor_member": member.name, "monthly_amount": [">", 0]},
                                ["name", "pledge_basis", "pledge_base", "monthly_amount", "pledge_months",
                                 "paid_amount", "creation"], as_dict=True)
        if p:
            today = frappe.utils.getdate(frappe.utils.nowdate())
            start = frappe.utils.getdate(p.creation)
            elapsed = (today.year - start.year) * 12 + today.month - start.month + 1
            elapsed = max(0, min(elapsed, frappe.utils.cint(p.pledge_months) or 12))
            due = frappe.utils.flt(p.monthly_amount) * elapsed - frappe.utils.flt(p.paid_amount)
            item["my_pledge"] = {"entry": p.name, "basis": p.pledge_basis, "base": p.pledge_base,
                                 "monthly": frappe.utils.flt(p.monthly_amount), "months": p.pledge_months,
                                 "months_so_far": elapsed, "paid": frappe.utils.flt(p.paid_amount),
                                 "due_now": max(due, 0)}
    out.append(item)
order = {"Running": 0, "Upcoming": 1, "Ended": 2}
out = sorted(out, key=lambda x: order.get(x["phase"], 3))
frappe.flags.sio_collections = out
