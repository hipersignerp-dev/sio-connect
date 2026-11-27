# My journey: today's ayah / hadith, streaks, this week's quiz, badges, friends and invites.
# @include journey
# @include quran
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
me_doc = frappe.db.get_value("SIO Member", m.name, ["name", "full_name", "username", "photo", "unit", "area",
                                                     "member_role"], as_dict=True)
rs_ = reading_series()
rows = rs_["rows"]
weeks = rs_["weeks"]
progress = series_state(m.name, rows, weeks)
reading = None
if rows:
    # each person walks the series at their own pace: today's lesson is the next one they haven't read
    reading = fill_ayah(rows[progress["pos"] % len(rows)])
    reading["audio"] = [u for u in (reading.get("audio") or "").split("\n") if u]
series_out = dict(progress)
series_out["weeks"] = weeks
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
# how my unit is doing today (everyone in it, no names: togetherness, not ranking)
unit_today = None
if m.unit:
    total = frappe.db.count("SIO Member", {"unit": m.unit, "status": "Active"})
    done = frappe.db.sql("""select count(distinct d.member) from `tabSIO Streak Day` d join `tabSIO Member` x
        on x.name = d.member where d.activity = 'Reading' and d.day = %s and x.unit = %s and x.status = 'Active'""",
                         (frappe.utils.nowdate(), m.unit))[0][0]
    unit_today = {"unit": m.unit, "read": done, "total": total}
frappe.response["message"] = {
    "me": card(me_doc), "reading": reading, "reading_streak": b["reading"], "attendance": b["attendance"],
    "quiz_streak": b["quiz"], "quiz": quiz, "badges": b["badges"], "friends": b["friends"], "invited": b["invited"],
    "friend_requests": pending, "unit_today": unit_today,
    "series": series_out,
    "pot": frappe.db.get_value("SIO Member", m.name, "noor_pot") or "blue",
    "invite_text": "Join me on SIO Connect, the app of SIO Ottapalam Area: programmes, photos, daily ayah streak, "
                   "quiz and more. " + frappe.utils.get_url("/go" + ("?i=" + me_doc.username if me_doc.username else ""))
                   + (" (my invite code: " + me_doc.username + ")" if me_doc.username else ""),
}
