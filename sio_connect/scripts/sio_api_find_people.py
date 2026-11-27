ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Find people by username or name to add as friends.
# --- journey helpers (shared): streaks, badges, friends ---
def jday(d):
    return frappe.utils.getdate(d)


def week_key(d):
    # Monday of the week a date falls in
    d = jday(d)
    return str(frappe.utils.add_days(d, -d.weekday()))


def streak_from_days(days, freeze=False):
    # days: dates something was done. current = run ending today (or yesterday, so it isn't lost before
    # today's turn); best = longest run ever. With freeze, one missed single day per week is forgiven
    # (a "streak freeze") so one busy day doesn't wipe out weeks of reading.
    have = set([str(jday(d)) for d in days])
    today = jday(frappe.utils.nowdate())
    d = today
    if str(d) not in have:
        d = frappe.utils.add_days(d, -1)
    cur = 0
    frozen = []
    used = set()
    while True:
        if str(jday(d)) in have:
            cur = cur + 1
        elif freeze and week_key(d) not in used and str(jday(frappe.utils.add_days(jday(d), -1))) in have:
            used.add(week_key(d))
            frozen.append(str(jday(d)))
        else:
            break
        d = frappe.utils.add_days(jday(d), -1)
    best = 0
    run = 0
    prev = None
    for x in sorted([jday(s) for s in have]):
        if prev is not None and frappe.utils.date_diff(x, prev) == 1:
            run = run + 1
        else:
            run = 1
        if run > best:
            best = run
        prev = x
    if cur > best:
        best = cur
    this_week = week_key(today)
    return {"current": cur, "best": best, "today": str(today) in have, "frozen": frozen,
            "freeze_left": 0 if (this_week in used) else 1,
            "week_days": len([x for x in have if week_key(x) == this_week])}


def member_days(member, activity):
    return [r[0] for r in frappe.db.sql(
        "select distinct day from `tabSIO Streak Day` where member = %s and activity = %s", (member, activity))]


POTS = ["blue", "green", "red", "purple", "orange", "teal", "pink", "gold"]


def reading_series():
    # the daily readings in series order: themed weeks, then the order inside each week
    rows = frappe.get_all("SIO Daily Reading", filters={"active": 1},
                          fields=["name", "kind", "reference", "text_en", "text_ml", "text_ar", "lesson_en", "lesson_ml", "audio",
                                  "filled_from_quran_api", "ml_audio", "series_week", "series_title", "series_title_ml", "series_emoji",
                                  "sort_order"])
    rows.sort(key=lambda r: (r.series_week or 999, r.sort_order or 0))
    weeks = []
    for i in range(len(rows)):
        r = rows[i]
        w = r.series_week or 0
        if not weeks or weeks[-1]["week"] != w:
            weeks.append({"week": w, "title": r.series_title or "", "title_ml": r.series_title_ml or "",
                          "emoji": r.series_emoji or "", "start": i, "size": 0})
        weeks[-1]["size"] = weeks[-1]["size"] + 1
    return {"rows": rows, "weeks": weeks}


def series_state(member, rows, weeks):
    # how far this person is: lessons done (days read, ever), today's lesson, weeks (chests) completed
    days = member_days(member, "Reading")
    done = len(days)
    today = frappe.utils.getdate(frappe.utils.nowdate())
    read_today = today in [frappe.utils.getdate(d) for d in days]
    pos = done - 1 if read_today else done
    n = len(rows) or 1
    completed = (done // n) * len(weeks) + len([w for w in weeks if w["start"] + w["size"] <= done % n])
    return {"done": done, "pos": max(pos, 0), "read_today": read_today, "length": len(rows),
            "completed_weeks": completed, "pots_unlocked": min(len(POTS), 1 + completed)}


def attendance_streak(member):
    # meetings in a row (most recent completed meetings this person was on the list for) where they were present
    rows = frappe.db.sql(
        """select a.status from `tabSIO Meeting Attendance` a join `tabSIO Meeting` m on m.name = a.parent
        where a.member = %s and m.status = 'Completed'
        order by m.meeting_date desc, m.meeting_time desc limit 60""", member)
    n = 0
    for r in rows:
        if r[0] == "Present":
            n = n + 1
        else:
            break
    present = len([r for r in rows if r[0] == "Present"])
    return {"current": n, "present": present}


def quiz_streak(member, area):
    today = frappe.utils.nowdate()
    quizzes = frappe.db.sql(
        """select name, ends_on from `tabSIO Quiz` where starts_on <= %s
        and (ifnull(area, '') = '' or area = %s) order by starts_on desc limit 52""", (today, area or "__none__"))
    done = set([r[0] for r in frappe.db.sql("select quiz from `tabSIO Quiz Attempt` where member = %s", member)])
    n = 0
    for q in quizzes:
        if q[0] in done:
            n = n + 1
        elif str(q[1]) >= today:
            continue  # still open: not missed yet
        else:
            break
    return {"current": n, "taken": len(done)}


def friend_ids(member):
    rows = frappe.db.sql(
        """select requester, addressee from `tabSIO Friend` where status = 'Accepted'
        and (requester = %s or addressee = %s)""", (member, member))
    return [r[1] if r[0] == member else r[0] for r in rows]


def friend_state(me_name, other):
    r = frappe.db.sql(
        """select name, requester, status from `tabSIO Friend`
        where (requester = %s and addressee = %s) or (requester = %s and addressee = %s) limit 1""",
        (me_name, other, other, me_name), as_dict=True)
    if not r:
        return {"state": "none", "request": None}
    r = r[0]
    if r.status == "Accepted":
        return {"state": "friends", "request": r.name}
    return {"state": "sent" if r.requester == me_name else "received", "request": r.name}


def duo_streak(a, b):
    da = set([str(jday(d)) for d in member_days(a, "Reading")])
    both = [d for d in member_days(b, "Reading") if str(jday(d)) in da]
    return streak_from_days(both)


def card(m):
    return {"member": m.name, "full_name": m.full_name, "username": m.get("username"), "photo": m.get("photo"),
            "unit": m.get("unit"), "member_role": m.get("member_role")}


def can_see_phone(viewer, target, friends=None):
    # viewer: my SIO Member row (or None); target: a row with name, unit, phone_visibility.
    # Leaders who can see the member list always can; otherwise the person's own choice decides.
    if not viewer or not target:
        return False
    if viewer.name == target.get("name"):
        return True
    if ctx["caps"].get("view_members") and (SCOPE_UNITS is None or target.get("unit") in SCOPE_UNITS):
        return True
    v = target.get("phone_visibility") or "Leaders only"
    if v == "All members":
        return True
    if v == "My unit":
        return bool(viewer.unit) and viewer.unit == target.get("unit")
    if v == "Friends":
        f = friends if friends is not None else set(friend_ids(viewer.name))
        return target.get("name") in f
    return False


def about(r):
    # the "who they are" fields for cards and profiles
    return {"life_stage": r.get("life_stage"), "profession": r.get("profession"), "workplace": r.get("workplace"),
            "current_city": r.get("current_city"), "campus": r.get("campus"), "course": r.get("course"),
            "home_town": r.get("home_town"), "mentor_topics": r.get("mentor_topics")}


BADGES = [
    # code, title, icon, what it takes. Kept to five that mean something (no attendance or giving badges).
    ("reader_7", "One week strong", "local_fire_department", "Read the daily ayah 7 days in a row"),
    ("reader_30", "Thirty days", "whatshot", "Read the daily ayah 30 days in a row"),
    ("first_programme", "First programme", "event_available", "Join your first SIO programme"),
    ("volunteer", "Volunteer", "volunteer_activism", "Finish a task for a programme"),
    ("quiz_full", "Full marks", "emoji_events", "Get every answer right in a weekly quiz"),
]


def badges_for(m):
    name = m.name
    reading = streak_from_days(member_days(name, "Reading"), True)
    att = attendance_streak(name)
    qs = quiz_streak(name, m.get("area"))
    full = frappe.db.sql("select count(*) from `tabSIO Quiz Attempt` where member = %s and score = total and total > 0",
                         name)[0][0]
    regs = frappe.db.count("SIO Event Registration", {"member": name, "status": ["!=", "Cancelled"]})
    tasks = frappe.db.count("SIO Event Task", {"assigned_to": name, "status": "Done"})
    paid = frappe.db.sql("select count(*) from `tabSIO Collection Entry` where contributor_member = %s and paid_amount > 0",
                         name)[0][0]
    invited = frappe.db.count("SIO Member", {"invited_by": name})
    friends = len(friend_ids(name))
    have = {
        "reader_3": (reading["best"], 3), "reader_7": (reading["best"], 7), "reader_30": (reading["best"], 30),
        "first_programme": (regs, 1), "meetings_10": (att["present"], 10), "attend_4": (att["current"], 4),
        "volunteer": (tasks, 1), "giver": (paid, 1), "quiz_first": (qs["taken"], 1), "quiz_full": (full, 1),
        "quiz_4": (qs["current"], 4), "inviter": (invited, 1), "friends_5": (friends, 5),
    }
    out = []
    for b in BADGES:
        got = have[b[0]]
        out.append({"code": b[0], "title": b[1], "icon": b[2], "how": b[3], "earned": got[0] >= got[1],
                    "progress": min(got[0], got[1]), "goal": got[1]})
    return {"badges": out, "reading": reading, "attendance": att, "quiz": qs, "friends": friends, "invited": invited}
# --- end journey helpers ---
m = ctx["member"]
q = (args.get("q") or "").strip().lower().lstrip("@")
if len(q) < 2:
    frappe.response["message"] = []
else:
    like = "%" + q + "%"
    rows = frappe.db.sql(
        """select name, full_name, username, photo, unit, member_role from `tabSIO Member`
        where status = 'Active' and name != %(me)s and (username like %(q)s or full_name like %(q)s)
        order by (username = %(exact)s) desc, full_name limit 30""",
        {"q": like, "me": m.name if m else "__none__", "exact": q}, as_dict=True)
    out = []
    for r in rows:
        c = card(r)
        c["friend"] = friend_state(m.name, r.name)["state"] if m else "none"
        out.append(c)
    frappe.response["message"] = out
