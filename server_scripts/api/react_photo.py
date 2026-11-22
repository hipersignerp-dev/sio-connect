# React to a programme photo (❤️ 🔥 😂 👏). One reaction per person per photo: the same emoji again removes it,
# another one replaces it. The person who uploaded the photo and the people tagged in it get a notice (once a day
# per person who reacts), so photos bring friends back into the app.
# @include albums
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
