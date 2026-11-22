# Home feed: recent programme photos that my friends or I are tagged in (newest first), with who is in each.
# @include journey
# @include albums
m = ctx["member"]
out = []
if m:
    who = friend_ids(m.name) + [m.name]
    tags = frappe.get_all("SIO Photo Tag", filters={"member": ["in", who]}, fields=["photo", "album", "creation"],
                          order_by="creation desc", limit=120)
    seen = []
    for t in tags:
        if t.photo in seen:
            continue
        seen.append(t.photo)
        a = frappe.db.get_value("SIO Album", t.album, ["name", "title", "album_date", "unit", "area"], as_dict=True)
        url = frappe.db.get_value("File", t.photo, "file_url")
        if not a or not url or not album_visible(a):
            continue
        people = []
        me_in = False
        for x in frappe.get_all("SIO Photo Tag", filters={"photo": t.photo}, pluck="member"):
            if x == m.name:
                me_in = True
            c = mini(x)
            if c:
                people.append(c)
        out.append({"name": t.photo, "file_url": url, "album": a.name, "album_title": a.title,
                    "album_date": a.album_date, "tags": people, "me": me_in, "creation": t.creation})
        if len(out) >= 30:
            break
add_reactions(out, m.name if m else None)
frappe.response["message"] = out
