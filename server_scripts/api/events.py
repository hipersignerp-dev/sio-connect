# Programmes I can see (SIO lib events), each with up to 3 friends who are going, so the card can show their faces.
# @include journey
rows = run_script("SIO lib events").sio_events
m = ctx["member"]
if m and rows:
    fr = friend_ids(m.name)
    if fr:
        names = [r.get("name") for r in rows]
        regs = frappe.get_all("SIO Event Registration", filters={"event": ["in", names], "member": ["in", fr],
                                                                "status": ["!=", "Cancelled"]},
                              fields=["event", "member"], limit=2000)
        going = {}
        for g in regs:
            going.setdefault(g.event, []).append(g.member)
        cards = {}
        for r in rows:
            ids = going.get(r.get("name"), [])
            out = []
            for x in ids[:3]:
                if x not in cards:
                    cards[x] = frappe.db.get_value("SIO Member", x, ["name", "full_name", "photo"], as_dict=True)
                if cards[x]:
                    out.append(cards[x])
            r["friends_going"] = out
            r["friends_going_count"] = len(ids)
frappe.response["message"] = rows
