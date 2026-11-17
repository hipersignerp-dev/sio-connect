# --- journey helpers (shared): streaks, badges, friends ---
def jday(d):
    return frappe.utils.getdate(d)


def streak_from_days(days):
    # days: dates something was done. current = run ending today (or yesterday, so it isn't lost before
    # today's turn); best = longest run ever
    have = set([str(jday(d)) for d in days])
    today = jday(frappe.utils.nowdate())
    d = today
    if str(d) not in have:
        d = frappe.utils.add_days(d, -1)
    cur = 0
    while str(jday(d)) in have:
        cur = cur + 1
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
    return {"current": cur, "best": best, "today": str(today) in have}


def member_days(member, activity):
    return [r[0] for r in frappe.db.sql(
        "select distinct day from `tabSIO Streak Day` where member = %s and activity = %s", (member, activity))]


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
    reading = streak_from_days(member_days(name, "Reading"))
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
