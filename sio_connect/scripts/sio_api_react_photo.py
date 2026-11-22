ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# React to a programme photo (❤️ 🔥 😂 👏). One reaction per person per photo: the same emoji again removes it,
# another one replaces it. The person who uploaded the photo and the people tagged in it get a notice (once a day
# per person who reacts), so photos bring friends back into the app.
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
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
photo = args.get("photo")
emoji = args.get("emoji")
if emoji not in REACTIONS:
    frappe.throw(_("Unknown reaction."))
f = frappe.db.get_value("File", photo, ["name", "attached_to_doctype", "attached_to_name", "owner"], as_dict=True)
if not f or f.attached_to_doctype != "SIO Album":
    frappe.throw(_("Photo not found."))
a = frappe.get_doc("SIO Album", f.attached_to_name)
if not album_visible(a):
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
old = frappe.db.get_value("SIO Photo Reaction", {"photo": photo, "member": m.name}, ["name", "emoji"], as_dict=True)
added = False
if old and old.emoji == emoji:
    frappe.delete_doc("SIO Photo Reaction", old.name, ignore_permissions=True)
elif old:
    frappe.db.set_value("SIO Photo Reaction", old.name, "emoji", emoji)
    added = True
else:
    frappe.get_doc({"doctype": "SIO Photo Reaction", "photo": photo, "album": a.name, "member": m.name,
                    "emoji": emoji}).insert(ignore_permissions=True)
    added = True
if added:
    people = set(frappe.get_all("SIO Photo Tag", filters={"photo": photo}, pluck="member"))
    up = frappe.db.get_value("SIO Member", {"user": f.owner}, "name")
    if up:
        people.add(up)
    people.discard(m.name)
    title = m.full_name + " reacted " + emoji + " to your photo"
    today = frappe.utils.nowdate()
    for who in people:
        if not frappe.db.exists("SIO Notice", {"member": who, "title": ["like", m.full_name + " reacted%"],
                                              "creation": [">=", today]}):
            frappe.get_doc({"doctype": "SIO Notice", "title": title, "message": "From the album: " + (a.title or ""),
                            "audience": "Person", "member": who}).insert(ignore_permissions=True)
r = add_reactions([{"name": photo}], m.name)[0]
frappe.response["message"] = {"reactions": r["reactions"], "my_reaction": r["my_reaction"]}
