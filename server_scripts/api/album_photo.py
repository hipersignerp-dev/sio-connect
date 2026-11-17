# Add a photo to an album (photo_data, resized on the phone) or delete one (photo, delete=1). Leaders only.
# @include albums
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
