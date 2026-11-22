# One album: its photos with who is tagged in each.
# @include albums
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
