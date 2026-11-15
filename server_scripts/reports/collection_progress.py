# Report "SIO Collection Progress": each unit's collection against its target.
ctx = run_script("SIO lib ctx").sio_ctx
collection = filters.get("collection")
if not collection:
    collection = frappe.db.get_value("SIO Collection", {"is_active": 1}, "name", order_by="target_amount desc, creation desc")
rows = run_script("SIO lib unit_progress", collection=collection).sio_unit_progress if collection else []
if not ctx["caps"]["all_units"]:
    rows = [r for r in rows if r["unit"] == ctx["unit"]]
columns = [
    {"fieldname": "unit", "label": "Unit", "fieldtype": "Link", "options": "SIO Unit", "width": 150},
    {"fieldname": "target", "label": "Target", "fieldtype": "Currency", "width": 120},
    {"fieldname": "collected", "label": "Received", "fieldtype": "Currency", "width": 120},
    {"fieldname": "pct", "label": "% of Target", "fieldtype": "Percent", "width": 100},
    {"fieldname": "to_target", "label": "Still to Target", "fieldtype": "Currency", "width": 130},
    {"fieldname": "offered", "label": "Offered", "fieldtype": "Currency", "width": 120},
    {"fieldname": "balance", "label": "Offered, Not Yet Paid", "fieldtype": "Currency", "width": 150},
    {"fieldname": "items", "label": "Items (value)", "fieldtype": "Currency", "width": 120},
    {"fieldname": "entries", "label": "Entries", "fieldtype": "Int", "width": 80},
]
target = sum([r["target"] for r in rows])
got = sum([r["collected"] for r in rows])
summary = [
    {"label": "Collection", "value": collection or "-", "datatype": "Data"},
    {"label": "Target", "value": target, "datatype": "Currency", "indicator": "Blue"},
    {"label": "Received", "value": got, "datatype": "Currency", "indicator": "Green"},
    {"label": "% of Target", "value": round(100.0 * got / target) if target else 0, "datatype": "Percent",
     "indicator": "Green"},
]
chart = {"data": {"labels": [r["unit"] for r in rows],
                  "datasets": [{"name": "Target", "values": [r["target"] for r in rows]},
                               {"name": "Received", "values": [r["collected"] for r in rows]}]},
         "type": "bar", "colors": ["#C4CCD5", "#1A62A8"]}
data = [columns, rows, None, chart, summary]
