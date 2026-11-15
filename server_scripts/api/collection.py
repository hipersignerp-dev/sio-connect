caps = ctx["caps"]
member = ctx["member"]
fields = ["name", "entry_type", "contributor_name", "contributor_type", "contributor_mobile", "unit",
          "pledged_amount", "paid_amount", "balance_amount", "in_kind_value", "in_kind_details", "status",
          "collected_by", "creation"]
if args.get("campaign"):
    camp = frappe.db.get_value("SIO Collection Campaign", args.get("campaign"),
                               ["name", "target_amount", "starts_on", "ends_on", "description", "is_active"], as_dict=True)
else:
    camp = frappe.db.get_value("SIO Collection Campaign", {"is_active": 1},
                               ["name", "target_amount", "starts_on", "ends_on", "description", "is_active"],
                               as_dict=True, order_by="creation desc")
if not camp:
    frappe.response["message"] = {"campaign": None}
else:
    out = {
        "campaign": {"name": camp.name, "target": frappe.utils.flt(camp.target_amount), "starts_on": camp.starts_on,
                     "ends_on": camp.ends_on, "description": camp.description},
        "my_pledges": [],
    }
    if member:
        out["my_pledges"] = frappe.get_all("SIO Collection Entry",
                                           filters={"campaign": camp.name, "contributor_member": member.name},
                                           fields=fields, order_by="creation desc")
    filters = {"campaign": camp.name}
    if args.get("status"):
        filters["status"] = args.get("status")
    if caps["view_collection_totals"]:
        if ctx["scope"]:
            filters["unit"] = ctx["scope"]
        out["totals"] = run_script("SIO lib totals", campaign=camp.name, unit=ctx["scope"] or "").sio_totals
        out["entries"] = frappe.get_all("SIO Collection Entry", filters=filters, fields=fields,
                                        order_by="creation desc", limit=200)
    elif caps["collect"] and member:
        filters["collected_by"] = member.name
        out["entries"] = frappe.get_all("SIO Collection Entry", filters=filters, fields=fields,
                                        order_by="creation desc", limit=200)
        mine = frappe.get_all("SIO Collection Entry", filters={"campaign": camp.name, "collected_by": member.name},
                              fields=["entry_type", "pledged_amount", "paid_amount", "balance_amount", "in_kind_value"],
                              limit=1000)
        pledged = 0
        collected = 0
        balance = 0
        in_kind = 0
        for e in mine:
            if e.entry_type == "In-kind":
                in_kind += frappe.utils.flt(e.in_kind_value)
            else:
                pledged += frappe.utils.flt(e.pledged_amount)
                collected += frappe.utils.flt(e.paid_amount)
                balance += frappe.utils.flt(e.balance_amount)
        out["totals"] = {"pledged": pledged, "collected": collected, "balance": balance, "in_kind": in_kind,
                         "entries": len(mine), "scope": "collected_by_me"}
    frappe.response["message"] = out
