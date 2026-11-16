# For visitors (no login): about SIO, upcoming public programmes, and whether online donation is set up.
st = frappe.db.get_value("SIO Settings", "SIO Settings",
                         ["org_name", "public_intro", "upi_id", "upi_payee_name", "min_donation", "public_collection",
                          "instagram", "threads", "facebook", "youtube", "whatsapp_channel", "website", "mission",
                          "vision_intro", "vision_points", "objectives", "hadith_text", "hadith_source"], as_dict=True) or {}


def points(text):
    # "Title: description" per line
    out = []
    for line in (text or "").split("\n"):
        line = line.strip()
        if not line:
            continue
        i = line.find(":")
        if i > 0:
            out.append({"title": line[:i].strip(), "text": line[i + 1:].strip()})
        else:
            out.append({"title": line, "text": ""})
    return out

leaders = frappe.get_all("SIO Leader", filters={"parent": "SIO Settings", "parenttype": "SIO Settings"},
                         fields=["leader_name", "designation", "phone", "photo"], order_by="idx asc")
for l in leaders:
    # only public files can be shown to visitors
    if l.photo and not l.photo.startswith("/files/"):
        l.photo = None
units = frappe.get_all("SIO Unit", filters={"active": 1}, fields=["name", "district as area"], order_by="name asc")
events = frappe.db.sql(
    """select name, title, event_type, starts_on, ends_on, venue, unit, description
    from `tabSIO Event`
    where open_to = 'Everyone' and status in ('Planning', 'Registrations Open', 'Registrations Closed')
        and starts_on >= %s
    order by starts_on asc limit 20""", frappe.utils.nowdate(), as_dict=True)
def plain(t):
    out = []
    inside = False
    for ch in t or "":
        if ch == "<":
            inside = True
        elif ch == ">":
            inside = False
        elif not inside:
            out.append(ch)
    return "".join(out).strip()

for e in events:
    e["description"] = plain(e.description)[:600]
frappe.response["message"] = {
    "org_name": st.get("org_name") or "SIO",
    "intro": st.get("public_intro"),
    "mission": st.get("mission"),
    "vision_intro": st.get("vision_intro"),
    "vision": points(st.get("vision_points")),
    "objectives": points(st.get("objectives")),
    "hadith": {"text": st.get("hadith_text"), "source": st.get("hadith_source")} if st.get("hadith_text") else None,
    "leaders": leaders,
    "units": units,
    "social": {k: st.get(k) for k in ("instagram", "threads", "facebook", "youtube", "whatsapp_channel", "website")
               if st.get(k)},
    "events": events,
    "can_donate": bool(st.get("upi_id") and st.get("public_collection")),
    "min_donation": frappe.utils.flt(st.get("min_donation")) or 10,
}
