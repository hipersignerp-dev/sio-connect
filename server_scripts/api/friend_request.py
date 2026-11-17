# Send a friend request (member), accept / decline one (request, accept=1/0), or unfriend (member, remove=1).
# @include journey
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))


def tell(member, title, msg):
    frappe.get_doc({"doctype": "SIO Notice", "title": title, "message": msg, "audience": "Person",
                    "member": member}).insert(ignore_permissions=True)


if args.get("request"):
    r = frappe.get_doc("SIO Friend", args.get("request"))
    if r.addressee != m.name:
        frappe.throw(_("This request is not for you."), frappe.PermissionError)
    if frappe.utils.cint(args.get("accept")):
        r.status = "Accepted"
        r.save(ignore_permissions=True)
        tell(r.requester, m.full_name + " accepted your friend request",
             "You can now see each other's journey and keep a reading streak together.")
        frappe.response["message"] = {"state": "friends"}
    else:
        frappe.delete_doc("SIO Friend", r.name, ignore_permissions=True)
        frappe.response["message"] = {"state": "none"}
else:
    other = args.get("member")
    if not other or other == m.name or not frappe.db.exists("SIO Member", other):
        frappe.throw(_("Pick a person."))
    st = friend_state(m.name, other)
    if frappe.utils.cint(args.get("remove")):
        if st["request"]:
            frappe.delete_doc("SIO Friend", st["request"], ignore_permissions=True)
        frappe.response["message"] = {"state": "none"}
    elif st["state"] == "received":
        r = frappe.get_doc("SIO Friend", st["request"])
        r.status = "Accepted"
        r.save(ignore_permissions=True)
        frappe.response["message"] = {"state": "friends"}
    elif st["state"] == "none":
        frappe.get_doc({"doctype": "SIO Friend", "requester": m.name, "addressee": other, "status": "Pending"}).insert(
            ignore_permissions=True)
        tell(other, m.full_name + " sent you a friend request",
             "Open SIO Connect → My journey → Friends to accept it.")
        frappe.response["message"] = {"state": "sent"}
    else:
        frappe.response["message"] = {"state": st["state"]}
