# Tag someone in an album photo (yourself, a friend, or anyone if you run the album); remove=1 to untag.
# The tagged person gets an update.
# @include albums
# @include journey
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
f = frappe.get_doc("File", args.get("photo"))
if f.attached_to_doctype != "SIO Album":
    frappe.throw(_("Photo not found."))
a = frappe.get_doc("SIO Album", f.attached_to_name)
if not album_visible(a):
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
who = args.get("member") or m.name
existing = frappe.db.get_value("SIO Photo Tag", {"photo": f.name, "member": who}, ["name", "tagged_by"], as_dict=True)
if frappe.utils.cint(args.get("remove")):
    if existing and (who == m.name or existing.tagged_by == m.name or can_manage_album(a)):
        frappe.delete_doc("SIO Photo Tag", existing.name, ignore_permissions=True)
    frappe.response["message"] = {"tagged": 0}
else:
    if who != m.name and not can_manage_album(a) and friend_state(m.name, who)["state"] != "friends":
        frappe.throw(_("You can tag yourself and your friends."))
    if not existing:
        frappe.get_doc({"doctype": "SIO Photo Tag", "photo": f.name, "album": a.name, "member": who,
                        "tagged_by": m.name}).insert(ignore_permissions=True)
        if who != m.name:
            frappe.get_doc({"doctype": "SIO Notice", "title": m.full_name + " tagged you in a photo 📸",
                            "message": "From " + a.title + ". Open Albums to see it and share it.",
                            "audience": "Person", "member": who}).insert(ignore_permissions=True)
    frappe.response["message"] = {"tagged": 1}
