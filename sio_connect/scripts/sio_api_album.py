ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# One album: its photos with who is tagged in each.
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
a = frappe.get_doc("SIO Album", args.get("name"))
if not album_visible(a):
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
photos = album_photos(a.name)
tags = {}
for t in frappe.get_all("SIO Photo Tag", filters={"album": a.name}, fields=["photo", "member"]):
    tags.setdefault(t.photo, []).append(t.member)
cards = {}
me = ctx["member"].name if ctx["member"] else None
for p in photos:
    p["tags"] = []
    for mbr in tags.get(p.name, []):
        if mbr not in cards:
            cards[mbr] = mini(mbr)
        if cards[mbr]:
            p["tags"].append(cards[mbr])
    p["me"] = bool(me) and me in tags.get(p.name, [])
add_reactions(photos, me)
frappe.response["message"] = {
    "name": a.name, "title": a.title, "event": a.event, "album_date": a.album_date, "unit": a.unit, "area": a.area,
    "cover": a.cover, "photos": photos, "can_manage": can_manage_album(a),
    "event_title": frappe.db.get_value("SIO Event", a.event, "title") if a.event else None,
}
