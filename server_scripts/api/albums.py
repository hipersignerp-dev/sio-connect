# Photo albums from programmes (newest first), with cover and how many photos I'm tagged in.
# @include albums
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
