# My journey: today's ayah / hadith, streaks, this week's quiz, badges, friends and invites.
# @include journey
# @include quran
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
me_doc = frappe.db.get_value("SIO Member", m.name, ["name", "full_name", "username", "photo", "unit", "area",
                                                     "member_role"], as_dict=True)
rows = frappe.get_all("SIO Daily Reading", filters={"active": 1},
                      fields=["name", "kind", "reference", "text_en", "text_ml", "text_ar", "lesson_en", "lesson_ml", "audio", "filled_from_quran_api"],
                      order_by="sort_order asc, creation asc")
reading = None
if rows:
    day_no = frappe.utils.date_diff(frappe.utils.nowdate(), "2026-01-01")
    reading = fill_ayah(rows[day_no % len(rows)])
    reading["audio"] = [u for u in (reading.get("audio") or "").split("\n") if u]
b = badges_for(me_doc)
today = frappe.utils.nowdate()
quiz = frappe.db.sql(
    """select name, title, ends_on from `tabSIO Quiz` where starts_on <= %s and ends_on >= %s
    and (ifnull(area, '') = '' or area = %s) order by starts_on desc limit 1""",
    (today, today, me_doc.area or "__none__"), as_dict=True)
quiz = quiz[0] if quiz else None
if quiz:
    att = frappe.db.get_value("SIO Quiz Attempt", {"quiz": quiz.name, "member": m.name}, ["score", "total"], as_dict=True)
    quiz["my_score"] = att.score if att else None
    quiz["my_total"] = att.total if att else None
    quiz["questions"] = frappe.db.count("SIO Quiz Question", {"parent": quiz.name, "parenttype": "SIO Quiz"})
pending = frappe.db.count("SIO Friend", {"addressee": m.name, "status": "Pending"})
frappe.response["message"] = {
    "me": card(me_doc), "reading": reading, "reading_streak": b["reading"], "attendance": b["attendance"],
    "quiz_streak": b["quiz"], "quiz": quiz, "badges": b["badges"], "friends": b["friends"], "invited": b["invited"],
    "friend_requests": pending,
    "invite_text": "Join SIO Connect, the app of SIO Ottapalam Area: programmes, meetings, daily ayah streak and more. "
                   "Download: https://github.com/hipersignerp-dev/sio-connect/releases/latest"
                   + (" and use my invite code " + me_doc.username + " when you register." if me_doc.username else ""),
}
