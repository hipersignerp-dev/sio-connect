# Posts from me and my friends, newest first.
# @include journey
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
who = friend_ids(m.name) + [m.name]
posts = frappe.get_all("SIO Post", filters={"member": ["in", who]},
                       fields=["name", "member", "kind", "badge", "title", "body", "cheers", "creation"],
                       order_by="creation desc", limit=60)
mine = set([c[0] for c in frappe.db.sql("select post from `tabSIO Post Cheer` where member = %s", m.name)])
cards = {}
for x in posts:
    if x.member not in cards:
        cards[x.member] = card(frappe.db.get_value("SIO Member", x.member, ["name", "full_name", "username", "photo",
                                                                            "unit", "member_role"], as_dict=True))
    x["by"] = cards[x.member]
    x["my_cheer"] = x.name in mine
frappe.response["message"] = posts
