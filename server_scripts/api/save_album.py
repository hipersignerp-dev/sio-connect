# Create or rename an album (leaders). Taking a programme fills the title, date, unit and area.
# @include albums
if not ctx["caps"]["manage_events"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
name = args.get("name")
doc = frappe.get_doc("SIO Album", name) if name else frappe.get_doc({"doctype": "SIO Album"})
if name and not can_manage_album(doc):
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
if frappe.utils.cint(args.get("delete")) and name:
    for f in album_photos(name):
        frappe.get_doc("File", f.name).delete(ignore_permissions=True)
    for t in frappe.get_all("SIO Photo Tag", filters={"album": name}, pluck="name"):
        frappe.delete_doc("SIO Photo Tag", t, ignore_permissions=True)
    frappe.delete_doc("SIO Album", name, ignore_permissions=True)
    frappe.response["message"] = {"deleted": 1}
else:
    ev = args.get("event") or None
    if ev:
        e = frappe.db.get_value("SIO Event", ev, ["title", "starts_on", "unit", "area"], as_dict=True)
        if not e:
            frappe.throw(_("Programme not found."))
        doc.event = ev
        doc.title = (args.get("title") or "").strip() or e.title
        doc.album_date = args.get("album_date") or frappe.utils.getdate(e.starts_on)
        doc.unit = e.unit
        doc.area = e.area or (frappe.db.get_value("SIO Unit", e.unit, "district") if e.unit else ctx["area"])
    else:
        doc.title = (args.get("title") or "").strip()
        doc.album_date = args.get("album_date") or doc.album_date or frappe.utils.nowdate()
        if not doc.area:
            doc.area = ctx["area"]
        if not doc.unit and SCOPE_UNITS is not None and not ctx["is_area_lead"] and ctx["member"]:
            doc.unit = ctx["member"].unit
    if not doc.title:
        frappe.throw(_("Give the album a title."))
    if doc.unit and not in_scope(doc.unit):
        frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
    if not name and ctx["member"]:
        doc.created_by_member = ctx["member"].name
    if name:
        doc.save(ignore_permissions=True)
    else:
        doc.insert(ignore_permissions=True)
    frappe.response["message"] = {"name": doc.name}
