ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Add a photo to an album (photo_data, resized on the phone) or delete one (photo, delete=1). Leaders only.
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
a = frappe.get_doc("SIO Album", args.get("album"))
if not can_manage_album(a):
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
if frappe.utils.cint(args.get("delete")):
    pid = args.get("photo")
    f = frappe.get_doc("File", pid)
    if f.attached_to_doctype != "SIO Album" or f.attached_to_name != a.name:
        frappe.throw(_("Photo not found."))
    for t in frappe.get_all("SIO Photo Tag", filters={"photo": pid}, pluck="name"):
        frappe.delete_doc("SIO Photo Tag", t, ignore_permissions=True)
    url = f.file_url
    f.delete(ignore_permissions=True)
    if a.cover == url:
        rest = album_photos(a.name)
        a.cover = rest[0].file_url if rest else None
else:
    data = args.get("photo_data")
    if not data:
        frappe.throw(_("Pick a photo."))
    if len(data) > 4000000:
        frappe.throw(_("The photo is too large."))
    f = frappe.get_doc({"doctype": "File", "file_name": "a-" + frappe.utils.generate_hash(length=16) + ".jpg",
                        "attached_to_doctype": "SIO Album", "attached_to_name": a.name, "is_private": 0,
                        "content": data, "decode": True}).insert(ignore_permissions=True)
    if not a.cover:
        a.cover = f.file_url
    url = f.file_url
a.photo_count = len(album_photos(a.name))
a.save(ignore_permissions=True)
frappe.response["message"] = {"count": a.photo_count, "url": url}
