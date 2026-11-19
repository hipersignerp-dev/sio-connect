# Someone's page (member or username): who they are, their badges and streaks; their posts if you are friends.
# @include journey
m = ctx["member"]
target = args.get("member")
if not target and args.get("username"):
    target = frappe.db.get_value("SIO Member", {"username": (args.get("username") or "").lower().lstrip("@")}, "name")
if not target and m:
    target = m.name
p = frappe.db.get_value("SIO Member", target, ["name", "full_name", "username", "photo", "unit", "area", "member_role",
                                                "status"], as_dict=True) if target else None
if not p or p.status != "Active":
    frappe.throw(_("Person not found."), frappe.DoesNotExistError)
me_name = m.name if m else None
st = {"state": "self", "request": None} if p.name == me_name else (friend_state(me_name, p.name) if me_name
                                                                    else {"state": "none", "request": None})
b = badges_for(p)
out = card(p)
out["friend"] = st
out["badges"] = [x for x in b["badges"] if x["earned"]]
if st["state"] == "self":
    out["all_badges"] = b["badges"]
out["reading"] = b["reading"]
out["attendance"] = b["attendance"]
out["quiz"] = b["quiz"]
out["friends"] = b["friends"]
out["posts"] = []
out["posts_count"] = frappe.db.count("SIO Post", {"member": p.name})
# programme photos this person is tagged in (albums are open to the area, so anyone who can open the page sees them)
ph = []
for t in frappe.get_all("SIO Photo Tag", filters={"member": p.name}, fields=["photo", "album"], order_by="creation desc",
                        limit=60):
    url = frappe.db.get_value("File", t.photo, "file_url")
    if url:
        ph.append({"name": t.photo, "file_url": url, "album": t.album,
                   "album_title": frappe.db.get_value("SIO Album", t.album, "title")})
out["photos"] = ph
if st["state"] in ("self", "friends"):
    out["posts"] = frappe.get_all("SIO Post", filters={"member": p.name},
                                  fields=["name", "kind", "badge", "title", "body", "cheers", "creation"],
                                  order_by="creation desc", limit=50)
    mine = set([c[0] for c in frappe.db.sql("select post from `tabSIO Post Cheer` where member = %s", me_name)])
    for x in out["posts"]:
        x["my_cheer"] = x.name in mine
if st["state"] == "friends":
    out["together"] = duo_streak(me_name, p.name)
frappe.response["message"] = out
