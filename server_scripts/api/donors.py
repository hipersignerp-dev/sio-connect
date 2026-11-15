# Everyone who has given: one line per person (matched by mobile, or by name when there is no mobile), with
# their phone, place, what they gave in each collection and what is still to come. Use it to ask again.
# Args: collection (compare against this one), show (all / not_yet / to_pay), unit, q.
# Unit admins see their unit, finance and admins every unit, a collector the people they collected from.
caps = ctx["caps"]
if not caps["view_donors"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
cond = ["1=1"]
params = {}
if not (caps["view_collection_totals"]):
    cond.append("e.collected_by = %(me)s")
    params["me"] = ctx["member"].name if ctx["member"] else "__none__"
elif ctx["scope"]:
    cond.append("e.unit = %(unit)s")
    params["unit"] = ctx["scope"]
elif args.get("unit"):
    cond.append("e.unit = %(unit)s")
    params["unit"] = args.get("unit")
q = (args.get("q") or "").strip()
if q:
    cond.append("(e.contributor_name like %(q)s or e.contributor_mobile like %(q)s or e.contributor_place like %(q)s)")
    params["q"] = "%" + q + "%"
rows = frappe.db.sql(
    """select e.collection, e.creation, e.entry_type, e.contributor_name, e.contributor_mobile,
        e.contributor_place, e.contributor_type, e.unit, e.offered_amount, e.paid_amount, e.balance_amount,
        e.items_value, e.status
    from `tabSIO Collection Entry` e
    where """ + " and ".join(cond) + """
    order by e.creation desc limit 5000""", params, as_dict=True)
people = {}
order = []
for r in rows:
    digits = "".join([ch for ch in (r.contributor_mobile or "") if ch.isdigit()])
    if len(digits) >= 10:
        key = digits[-10:]
    else:
        key = "n:" + (r.contributor_name or "").strip().lower()
    d = people.get(key)
    if not d:
        d = {"key": key, "name": r.contributor_name, "mobile": r.contributor_mobile, "place": r.contributor_place,
             "type": r.contributor_type, "unit": r.unit, "given": 0, "offered": 0, "balance": 0, "items": 0,
             "times": 0, "last_date": r.creation, "by_collection": {}}
        people[key] = d
        order.append(key)
    if not d["place"] and r.contributor_place:
        d["place"] = r.contributor_place
    if not d["mobile"] and r.contributor_mobile:
        d["mobile"] = r.contributor_mobile
    paid = frappe.utils.flt(r.paid_amount)
    items = frappe.utils.flt(r.items_value)
    d["given"] = d["given"] + paid + items
    d["items"] = d["items"] + items
    if r.entry_type == "Offer":
        d["offered"] = d["offered"] + frappe.utils.flt(r.offered_amount)
    d["balance"] = d["balance"] + frappe.utils.flt(r.balance_amount)
    d["times"] = d["times"] + 1
    amt = paid + items
    if r.entry_type == "Offer":
        amt = max(paid, frappe.utils.flt(r.offered_amount))
    bc = d["by_collection"]
    bc[r.collection] = bc.get(r.collection, 0) + amt
# people saved in the donor list (some may not have given yet)
dcond = {}
if not caps["view_collection_totals"]:
    dcond["added_by"] = ctx["member"].name if ctx["member"] else "__none__"
elif ctx["scope"]:
    dcond["unit"] = ctx["scope"]
elif args.get("unit"):
    dcond["unit"] = args.get("unit")
saved = frappe.get_all("SIO Donor", filters=dcond,
                       fields=["name", "donor_name", "mobile", "place", "donor_type", "unit", "notes", "creation"],
                       order_by="creation desc", limit=5000)
for s in saved:
    if q and q.lower() not in ((s.donor_name or "") + " " + (s.mobile or "") + " " + (s.place or "")).lower():
        continue
    digits = "".join([ch for ch in (s.mobile or "") if ch.isdigit()])
    if len(digits) >= 10:
        key = digits[-10:]
    else:
        key = "n:" + (s.donor_name or "").strip().lower()
    d = people.get(key)
    if not d:
        d = {"key": key, "name": s.donor_name, "mobile": s.mobile, "place": s.place, "type": s.donor_type,
             "unit": s.unit, "given": 0, "offered": 0, "balance": 0, "items": 0, "times": 0, "last_date": None,
             "by_collection": {}}
        people[key] = d
        order.append(key)
    d["donor"] = s.name
    d["name"] = s.donor_name
    d["notes"] = s.notes
    if s.mobile:
        d["mobile"] = s.mobile
    if s.place:
        d["place"] = s.place
    if s.donor_type:
        d["type"] = s.donor_type
selected = args.get("collection")
show = args.get("show") or "all"
out = []
for key in order:
    d = people[key]
    d["this_time"] = d["by_collection"].get(selected) if selected else None
    d["collections"] = [{"collection": k, "amount": d["by_collection"][k]} for k in d["by_collection"]]
    d.pop("by_collection")
    if show == "not_yet" and d["this_time"] is not None:
        continue
    if show == "to_pay" and d["balance"] <= 0:
        continue
    out.append(d)
frappe.response["message"] = {"donors": out, "count": len(out),
                              "with_mobile": len([d for d in out if d["mobile"]])}
