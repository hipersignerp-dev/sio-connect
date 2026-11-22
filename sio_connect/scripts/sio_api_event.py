ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# --- event task helpers (shared) ---
def task_event(ev_name):
    ev = frappe.db.get_value("SIO Event", ev_name, ["name", "title", "unit", "area", "starts_on", "venue", "status"],
                             as_dict=True)
    if not ev:
        frappe.throw(_("Event not found."), frappe.DoesNotExistError)
    return ev


def can_manage_event(ev):
    # office bearers of the event's unit (or, for an area-wide event, the area leaders / admins)
    if not ctx["caps"]["manage_events"]:
        return False
    if ev.unit:
        return in_scope(ev.unit)
    return SCOPE_UNITS is None or (ctx["is_area_lead"] and ev.area == ctx["area"])


def is_coordinator(ev_name):
    if not ctx["member"]:
        return False
    return bool(frappe.db.exists("SIO Event Team Member", {"parent": ev_name, "parenttype": "SIO Event",
                                                           "member": ctx["member"].name,
                                                           "responsibility": ["like", "%oordinator%"]}))


def can_run_tasks(ev):
    return can_manage_event(ev) or is_coordinator(ev.name)


def notify_person(member, title, message, event=None, task=None):
    if not member:
        return
    frappe.get_doc({"doctype": "SIO Notice", "title": title, "message": message, "audience": "Person",
                    "member": member, "event": event, "task": task}).insert(ignore_permissions=True)


def when_text(dt):
    return frappe.utils.format_datetime(dt, "EEE d MMM, h:mm a") if dt else ""
# --- end event task helpers ---
# One event, with its team, tasks and expenses: office bearers see budget, spent, pending and every expense;
# members see their own claims for the event.
found = [e for e in run_script("SIO lib events", limit=500, since_days=3650).sio_events if e.name == args.get("name")]
if not found:
    frappe.throw(_("Event not found."), frappe.DoesNotExistError)
out = found[0]
ev = frappe.db.get_value("SIO Event", out.name, ["description", "budget", "unit"], as_dict=True)
out["description"] = ev.description
filters = {"event": out.name}
see_all = SCOPE_UNITS is None or (ctx["is_unit_admin"] and ev.unit and in_scope(ev.unit))
if see_all:
    pass
elif ctx["is_unit_admin"]:
    filters["unit"] = ["in", scope_list()]
elif ctx["member"]:
    filters["claimed_by"] = ctx["member"].name
else:
    filters["name"] = "__none__"
expenses = frappe.get_all("SIO Expense Claim", filters=filters,
                          fields=["name", "description", "category", "amount", "expense_date", "status",
                                  "claimed_by_name", "unit", "paid_on", "paid_from"],
                          order_by="expense_date desc, creation desc")
out["expenses"] = expenses
if ctx["is_unit_admin"] or ctx["is_finance"]:
    paid = 0
    approved = 0
    pending = 0
    by_category = {}
    for x in expenses:
        amt = frappe.utils.flt(x.amount)
        if x.status == "Paid":
            paid += amt
        elif x.status == "Approved":
            approved += amt
        elif x.status == "Pending":
            pending += amt
        if x.status in ("Paid", "Approved"):
            by_category[x.category or "Other"] = by_category.get(x.category or "Other", 0) + amt
    budget = frappe.utils.flt(ev.budget)
    out["expense_summary"] = {
        "budget": budget,
        "paid": paid,
        "approved": approved,
        "spent": paid + approved,
        "pending": pending,
        "remaining": budget - paid - approved if budget else None,
        "by_category": sorted([{"category": k, "amount": by_category[k]} for k in by_category],
                              key=lambda r: -r["amount"]),
        "scope": "all" if see_all else "my unit",
    }
# team and tasks
evr = task_event(out.name)
boss = can_run_tasks(evr)
out["can_manage_tasks"] = boss
out["team"] = frappe.get_all("SIO Event Team Member", filters={"parent": out.name, "parenttype": "SIO Event"},
                             fields=["member", "member_name", "responsibility"], order_by="idx asc")
tfilters = {"event": out.name}
on_team = ctx["member"] and ctx["member"].name in [t.member for t in out["team"]]
if not (boss or on_team):
    tfilters["assigned_to"] = ctx["member"].name if ctx["member"] else "__none__"
tasks = frappe.get_all("SIO Event Task", filters=tfilters,
                       fields=["name", "title", "responsibility", "assigned_to", "assigned_name", "due_on",
                               "status", "notes", "last_reminded", "creation"],
                       order_by="creation asc")
# open first, then by due date (no date last), then done
out["tasks"] = sorted(tasks, key=lambda t: (t.status == "Done", t.due_on is None, str(t.due_on or "")))
if boss:
    # people who can be put on the team: the event's unit, or its area, or everyone
    pf = {"status": "Active"}
    if evr.unit:
        pf["unit"] = evr.unit
    elif evr.area:
        pf["area"] = evr.area
    out["people"] = frappe.get_all("SIO Member", filters=pf, fields=["name", "full_name", "unit", "member_role"],
                                   order_by="full_name asc", limit=500)
# rating and certificate: people who attended can rate the programme and get a participation certificate
me = ctx["member"]
att = bool(me) and frappe.db.exists("SIO Event Registration", {"event": out.name, "member": me.name, "status": "Attended"})
ended = out.get("status") == "Completed" or (out.get("ends_on") or out.get("starts_on")) and \
    frappe.utils.get_datetime(out.get("ends_on") or out.get("starts_on")) < frappe.utils.now_datetime()
out["attended"] = 1 if att else 0
out["can_rate"] = 1 if (att and ended) else 0
mine = frappe.db.get_value("SIO Event Feedback", {"event": out.name, "member": me.name}, ["rating", "comment"],
                           as_dict=True) if me else None
out["my_rating"] = mine.rating if mine else None
out["my_comment"] = mine.comment if mine else None
if boss or ctx["caps"].get("manage_events"):
    fb = frappe.get_all("SIO Event Feedback", filters={"event": out.name}, fields=["rating", "comment", "member"])
    rated = [f.rating for f in fb if f.rating]
    out["ratings"] = {"count": len(rated), "average": round(sum(rated) / len(rated), 1) if rated else None,
                      "comments": [{"comment": f.comment,
                                    "full_name": frappe.db.get_value("SIO Member", f.member, "full_name")}
                                   for f in fb if f.comment][:30]}
if att:
    out["certificate"] = {"full_name": me.full_name, "unit": me.unit, "area": ctx["area"],
                          "code": frappe.utils.sha256_hash(out.name + ":" + me.name)[:10].upper()}
frappe.response["message"] = out
