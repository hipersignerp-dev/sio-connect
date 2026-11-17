# Photos I'm tagged in, newest first.
# @include albums
m = ctx["member"]
out = []
if m:
    for t in frappe.get_all("SIO Photo Tag", filters={"member": m.name}, fields=["photo", "album"],
                            order_by="creation desc", limit=200):
        url = frappe.db.get_value("File", t.photo, "file_url")
        if url:
            out.append({"name": t.photo, "file_url": url, "album": t.album,
                        "album_title": frappe.db.get_value("SIO Album", t.album, "title")})
frappe.response["message"] = out
