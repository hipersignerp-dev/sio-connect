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
# --- end album helpers ---
