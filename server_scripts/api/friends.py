# My friends with their streaks and our streak together, plus friend requests.
# @include journey
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
friends = []
for fid in friend_ids(m.name):
    f = frappe.db.get_value("SIO Member", fid, ["name", "full_name", "username", "photo", "unit", "member_role"],
                            as_dict=True)
    if not f:
        continue
    c = card(f)
    c["reading"] = streak_from_days(member_days(fid, "Reading"), True)
    c["together"] = duo_streak(m.name, fid)
    friends.append(c)
friends = sorted(friends, key=lambda x: -x["together"]["current"])
incoming = []
for r in frappe.get_all("SIO Friend", filters={"addressee": m.name, "status": "Pending"}, fields=["name", "requester"]):
    f = frappe.db.get_value("SIO Member", r.requester, ["name", "full_name", "username", "photo", "unit", "member_role"],
                            as_dict=True)
    if f:
        c = card(f)
        c["request"] = r.name
        incoming.append(c)
outgoing = []
for r in frappe.get_all("SIO Friend", filters={"requester": m.name, "status": "Pending"}, fields=["name", "addressee"]):
    f = frappe.db.get_value("SIO Member", r.addressee, ["name", "full_name", "username", "photo", "unit", "member_role"],
                            as_dict=True)
    if f:
        outgoing.append(card(f))
frappe.response["message"] = {"friends": friends, "incoming": incoming, "outgoing": outgoing}
