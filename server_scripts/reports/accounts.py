# Report "SIO Accounts": money in / out / balance, filtered by dates, unit, collection (fund) and event.
a = run_script("SIO lib accounts", from_date=filters.get("from_date") or "", to_date=filters.get("to_date") or "",
               unit=filters.get("unit") or "", collection=filters.get("collection") or "",
               event=filters.get("event") or "").sio_accounts
columns = [
    {"fieldname": "date", "label": "Date", "fieldtype": "Date", "width": 100},
    {"fieldname": "type", "label": "In / Out", "fieldtype": "Data", "width": 80},
    {"fieldname": "title", "label": "For", "fieldtype": "Data", "width": 220},
    {"fieldname": "party", "label": "From / Paid To", "fieldtype": "Data", "width": 170},
    {"fieldname": "unit", "label": "Unit", "fieldtype": "Link", "options": "SIO Unit", "width": 120},
    {"fieldname": "collection", "label": "Collection / Fund", "fieldtype": "Link", "options": "SIO Collection", "width": 170},
    {"fieldname": "event", "label": "Event", "fieldtype": "Link", "options": "SIO Event", "width": 110},
    {"fieldname": "mode", "label": "Mode", "fieldtype": "Data", "width": 90},
    {"fieldname": "money_in", "label": "In", "fieldtype": "Currency", "width": 120},
    {"fieldname": "money_out", "label": "Out", "fieldtype": "Currency", "width": 120},
    {"fieldname": "balance", "label": "Balance", "fieldtype": "Currency", "width": 130},
    {"fieldname": "ref", "label": "Record", "fieldtype": "Data", "width": 140},
]
result = [{"date": a["from_date"], "type": "", "title": "Opening balance", "balance": a["opening"]}]
for r in a["rows"]:
    result.append({
        "date": r["date"], "type": r["type"], "title": r["title"], "party": r["party"], "unit": r["unit"],
        "collection": r["collection"], "event": r["event"], "mode": r["mode"],
        "money_in": r["amount"] if r["type"] == "In" else None,
        "money_out": r["amount"] if r["type"] == "Out" else None,
        "balance": r["balance"], "ref": r["ref"],
    })
result.append({"date": a["to_date"], "type": "", "title": "Closing balance", "money_in": a["in"],
               "money_out": a["out"], "balance": a["closing"]})
summary = [
    {"label": "Opening", "value": a["opening"], "datatype": "Currency", "indicator": "Blue"},
    {"label": "Money In", "value": a["in"], "datatype": "Currency", "indicator": "Green"},
    {"label": "Money Out", "value": a["out"], "datatype": "Currency", "indicator": "Red"},
    {"label": "Balance", "value": a["closing"], "datatype": "Currency", "indicator": "Blue"},
    {"label": "Approved, to pay", "value": a["to_pay"], "datatype": "Currency", "indicator": "Orange"},
]
data = [columns, result, None, None, summary]
