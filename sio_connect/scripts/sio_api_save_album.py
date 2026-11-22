ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Create or rename an album (leaders). Taking a programme fills the title, date, unit and area.
# --- album helpers (shared) ---
def album_visible(a):
    # everyone in the album's area (or everywhere if no area); admins see all
    if SCOPE_UNITS is None:
        return True
    if not a.get("area") or a.get("area") == ctx["area"]:
        return True
    return bool(a.get("unit")) and in_scope(a.get("unit"))


def can_manage_album(a):
    if not ctx["caps"]["manage_events"]:
        return False
    if SCOPE_UNITS is None:
        return True
    if a.get("unit"):
        return in_scope(a.get("unit"))
    return bool(ctx["is_area_lead"]) and a.get("area") == ctx["area"]


def mini(member):
    m = frappe.db.get_value("SIO Member", member, ["name", "full_name", "username", "photo", "unit"], as_dict=True)
    if not m:
        return None
    return {"member": m.name, "full_name": m.full_name, "username": m.username, "photo": m.photo, "unit": m.unit}


def album_photos(album):
    return frappe.get_all("File", filters={"attached_to_doctype": "SIO Album", "attached_to_name": album,
                                   "attached_to_field": ["is", "not set"]},
                          fields=["name", "file_url", "creation"], order_by="creation asc")
REACTIONS = ["❤️", "🔥", "😂", "👏"]


def add_reactions(photos, me):
    # puts "reactions" ({emoji: count}) and "my_reaction" on each photo dict (keyed by File name)
    names = [p["name"] for p in photos]
    by = {}
    if names:
        for r in frappe.get_all("SIO Photo Reaction", filters={"photo": ["in", names]}, fields=["photo", "member", "emoji"]):
            by.setdefault(r.photo, []).append(r)
    for p in photos:
        counts = {}
        mine = None
        for r in by.get(p["name"], []):
            counts[r.emoji] = counts.get(r.emoji, 0) + 1
            if me and r.member == me:
                mine = r.emoji
        p["reactions"] = counts
        p["my_reaction"] = mine
    return photos
# --- end album helpers ---
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
