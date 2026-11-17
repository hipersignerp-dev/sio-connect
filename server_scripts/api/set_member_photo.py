# Add, change or remove a student's photo. Anyone can set their own; unit admins and area admins can set
# the photo of students they manage. The image is resized on the phone; it is stored as a public file with a
# random name so the app can show it without a sign-in header.
target = args.get("member") or (ctx["member"].name if ctx["member"] else None)
if not target:
    frappe.throw(_("Your student record is not set up yet."))
own = ctx["member"] and ctx["member"].name == target
if not own:
    if not ctx["caps"]["add_members"]:
        frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
    unit = frappe.db.get_value("SIO Member", target, "unit")
    if not in_scope(unit):
        frappe.throw(_("That belongs to another unit."), frappe.PermissionError)
if not frappe.db.exists("SIO Member", target):
    frappe.throw(_("Student not found."))
old = frappe.get_all("File", filters={"attached_to_doctype": "SIO Member", "attached_to_name": target,
                                      "attached_to_field": "photo"}, pluck="name")
url = None
data = args.get("photo_data")
if data:
    if len(data) > 3000000:
        frappe.throw(_("The photo is too large."))
    f = frappe.get_doc({
        "doctype": "File",
        "file_name": "m-" + frappe.utils.generate_hash(length=16) + ".jpg",
        "attached_to_doctype": "SIO Member",
        "attached_to_name": target,
        "attached_to_field": "photo",
        "is_private": 0,
        "content": data,
        "decode": True,
    })
    f.insert(ignore_permissions=True)
    url = f.file_url
frappe.db.set_value("SIO Member", target, "photo", url)
for n in old:
    try:
        frappe.get_doc("File", n).delete(ignore_permissions=True)
    except Exception:
        pass
frappe.response["message"] = {"name": target, "photo": url}
