ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Delete my account (Google Play requirement). Removes sign-in, contact details, location, username, friends,
# posts, cheers, photo tags, streaks and quiz answers. Records the organisation must keep (money, attendance)
# stay, under "Deleted member" without contact details.
if (args.get("confirm") or "") != "DELETE":
    frappe.throw(_("Type DELETE to confirm."))
m = ctx["member"]
user = ctx["user"]
if "System Manager" in frappe.get_roles(user) or (m and m.get("member_role") in ("Area Admin", "Finance")):
    frappe.throw(_("Admin accounts can't be deleted from the app. Ask another area admin."))
if m:
    me = m.name
    for f in frappe.get_all("SIO Friend", or_filters={"requester": me, "addressee": me}, pluck="name"):
        frappe.delete_doc("SIO Friend", f, ignore_permissions=True)
    for p in frappe.get_all("SIO Post", filters={"member": me}, pluck="name"):
        for c in frappe.get_all("SIO Post Cheer", filters={"post": p}, pluck="name"):
            frappe.delete_doc("SIO Post Cheer", c, ignore_permissions=True)
        frappe.delete_doc("SIO Post", p, ignore_permissions=True)
    for dt in ("SIO Post Cheer", "SIO Photo Tag", "SIO Streak Day", "SIO Quiz Attempt"):
        for n in frappe.get_all(dt, filters={"member": me}, pluck="name"):
            frappe.delete_doc(dt, n, ignore_permissions=True)
    frappe.db.set_value("SIO Member", me, {
        "full_name": "Deleted member", "photo": None, "mobile": None, "email": None, "username": None,
        "user": None, "latitude": None, "longitude": None, "location_note": None, "campus": None, "course": None,
        "home_town": None, "status": "Inactive", "membership_note": None, "books_read": None})
for t in frappe.get_all("SIO Device Token", filters={"user": user}, pluck="name"):
    frappe.delete_doc("SIO Device Token", t, ignore_permissions=True)
u = frappe.get_doc("User", user)
u.enabled = 0
u.api_secret = None
u.first_name = "Deleted"
u.last_name = None
u.mobile_no = None
u.user_image = None
u.save(ignore_permissions=True)
frappe.response["message"] = {"deleted": 1}
