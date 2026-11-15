# Open collections, and the entries of one of them (args: collection, status).
caps = ctx["caps"]
member = ctx["member"]
fields = ["name", "collection", "entry_type", "contributor_name", "contributor_type", "contributor_mobile", "unit",
          "offered_amount", "paid_amount", "balance_amount", "items_value", "items_given", "status",
          "collected_by", "creation"]
collections = run_script("SIO lib collections").sio_collections
selected = None
for c in collections:
    if c["name"] == args.get("collection"):
        selected = c
if not selected and collections:
    selected = collections[0]
out = {"collections": collections, "collection": selected, "my_offers": [], "entries": None, "totals": None,
       "units": []}
if selected:
    out["totals"] = selected["totals"]
    # each unit's progress against its target: everyone sees their own unit, finance and admins all units
    progress = run_script("SIO lib unit_progress", collection=selected["name"]).sio_unit_progress
    if caps["all_units"]:
        out["units"] = progress
    else:
        out["units"] = [u for u in progress if u["unit"] == ctx["unit"]]
    if member:
        out["my_offers"] = frappe.get_all("SIO Collection Entry",
                                          filters={"collection": selected["name"], "contributor_member": member.name},
                                          fields=fields, order_by="creation desc")
    filters = {"collection": selected["name"]}
    if args.get("status"):
        filters["status"] = args.get("status")
    if caps["view_collection_totals"]:
        if ctx["scope"]:
            filters["unit"] = ctx["scope"]
        out["entries"] = frappe.get_all("SIO Collection Entry", filters=filters, fields=fields,
                                        order_by="creation desc", limit=200)
    elif caps["collect"] and member:
        filters["collected_by"] = member.name
        out["entries"] = frappe.get_all("SIO Collection Entry", filters=filters, fields=fields,
                                        order_by="creation desc", limit=200)
frappe.response["message"] = out
