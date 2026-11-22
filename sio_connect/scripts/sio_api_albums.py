ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Photo albums from programmes (newest first), with cover and how many photos I'm tagged in.
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
rows = frappe.get_all("SIO Album", fields=["name", "title", "event", "album_date", "unit", "area", "cover",
                                           "photo_count", "creation"],
                      order_by="album_date desc, creation desc", limit=200)
me = ctx["member"].name if ctx["member"] else "__none__"
mine = {}
for r in frappe.db.sql("select album, count(*) from `tabSIO Photo Tag` where member = %s group by album", me):
    mine[r[0]] = r[1]
out = []
for r in rows:
    if not album_visible(r):
        continue
    r["me_in"] = mine.get(r.name, 0)
    r["event_title"] = frappe.db.get_value("SIO Event", r.event, "title") if r.event else None
    out.append(r)
frappe.response["message"] = {"albums": out, "can_add": bool(ctx["caps"]["manage_events"]),
                              "my_photos": sum(mine.values())}
