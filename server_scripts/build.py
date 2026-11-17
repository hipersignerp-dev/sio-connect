"""Builds the Server Script records for a site without bench access (e.g. through the ERP connector).

    python3 server_scripts/build.py          -> server_scripts/dist/*.json, one Server Script each

API scripts use the same method names as the sio_connect Python app (sio_connect.api.mobile.*), so the
phone app works with either. Each API script except the guest ones starts with PRELUDE, which loads the
caller's context from the "SIO lib ctx" script. Each script runs with its own frappe.flags, and run_script()
returns the called script's flags, so library results are read from the return value.
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))

PRELUDE = '''ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

'''

LIBS = ["ctx", "events", "notices", "totals", "collections", "unit_progress", "accounts"]

GUEST_API = {
    # file: (method, rate limit (count, seconds) or None)
    "units": ("sio_connect.api.auth.units", None),
    "register": ("sio_connect.api.auth.register", (5, 3600)),
    "public_info": ("sio_connect.api.public.info", (120, 3600)),
    "public_donate": ("sio_connect.api.public.donate", (10, 3600)),
    "public_donation_paid": ("sio_connect.api.public.donation_paid", (20, 3600)),
}
API = {
    "enable_biometric": "sio_connect.api.auth.enable_biometric",
    "disable_biometric": "sio_connect.api.auth.disable_biometric",
}
MOBILE = ["me", "update_my_profile", "home", "meetings", "meeting", "rsvp", "save_attendance", "schedule_meeting",
          "events", "event", "register_event", "collection", "add_collection_entry", "add_payment", "expenses",
          "claim_expense", "set_expense_status", "notices", "send_notice", "members", "approve_member", "accounts",
          "collection_form", "manage_collections", "save_collection", "delete_collection", "save_event",
          "delete_event", "save_member", "manage_units", "save_unit", "donors", "manage_areas", "save_area", "save_donor", "fund_requests", "request_fund", "set_fund_request", "set_member_photo", "save_meeting_summary", "ai_summary", "save_event_team", "save_task", "delete_task", "remind_task", "my_tasks", "journey", "read_today", "quiz", "submit_quiz", "quizzes", "save_quiz", "set_username", "find_people", "friend_request", "friends", "profile", "feed", "create_post", "post_action", "unit_board", "suggest_people", "nudge", "find_members"]
for m in MOBILE:
    API[m] = f"sio_connect.api.mobile.{m}"

EVENTS = [
    # (script name, doctype, event, file)
    ("SIO Member validate", "SIO Member", "Before Save", "member_before_save"),
    ("SIO Member roles", "SIO Member", "After Save", "member_after_save"),
    ("SIO Meeting counts", "SIO Meeting", "Before Save", "meeting_before_save"),
    ("SIO Registration validate", "SIO Event Registration", "Before Save", "registration_before_save"),
    ("SIO Registration totals", "SIO Event Registration", "After Save", "event_totals"),
    ("SIO Registration totals on delete", "SIO Event Registration", "After Delete", "event_totals"),
    ("SIO Collection amounts", "SIO Collection Entry", "Before Save", "collection_before_save"),
    ("SIO Expense validate", "SIO Expense Claim", "Before Save", "expense_before_save"),
    ("SIO Expense totals", "SIO Expense Claim", "After Save", "event_totals"),
    ("SIO Expense totals on delete", "SIO Expense Claim", "After Delete", "event_totals"),
    ("SIO Fund Request spent", "SIO Expense Claim", "After Save", "fund_request_spent"),
    ("SIO Fund Request spent on delete", "SIO Expense Claim", "After Delete", "fund_request_spent"),
    ("SIO Notice recipients", "SIO Notice", "Before Insert", "notice_before_insert"),
    ("SIO Notice email", "SIO Notice", "After Insert", "notice_after_insert"),
    ("SIO Device revoke", "SIO Device Token", "After Save", "device_after_save"),
    ("SIO Collection targets", "SIO Collection", "Before Save", "collection_targets"),
    ("SIO Unit area leads", "SIO Unit", "After Save", "unit_after_save"),
    ("SIO Event announce", "SIO Event", "After Insert", "event_after_insert"),
]


PQ = {  # permission query scripts: file -> (doctype, label)
    "sio_member": ("SIO Member", "Member"), "sio_collection_entry": ("SIO Collection Entry", "Collection Entry"),
    "sio_expense_claim": ("SIO Expense Claim", "Expense Claim"), "sio_meeting": ("SIO Meeting", "Meeting"),
    "sio_event": ("SIO Event", "Event"), "sio_notice": ("SIO Notice", "Notice"),
}


REPORTS = [
    # (report name, ref doctype, file, filters)
    ("SIO Accounts", "SIO Expense Claim", "accounts", [
        ("from_date", "From Date", "Date", None), ("to_date", "To Date", "Date", None),
        ("unit", "Unit", "Link", "SIO Unit"), ("collection", "Collection / Fund", "Link", "SIO Collection"),
        ("event", "Event", "Link", "SIO Event")]),
    ("SIO Collection Progress", "SIO Collection Entry", "collection_progress", [
        ("collection", "Collection", "Link", "SIO Collection")]),
    ("SIO Event Expenses", "SIO Expense Claim", "event_expenses", [
        ("from_date", "Events From", "Date", None), ("to_date", "Events To", "Date", None),
        ("unit", "Unit", "Link", "SIO Unit")]),
]
REPORT_ROLES = ["SIO Unit Admin", "SIO Finance", "SIO Admin", "System Manager"]


def reports():
    out = []
    for name, ref, f, flt in REPORTS:
        out.append({
            "report_name": name, "ref_doctype": ref, "report_type": "Script Report", "is_standard": "No",
            "module": "SIO Connect", "report_script": read("reports", f"{f}.py"),
            "filters": [{"fieldname": a, "label": b, "fieldtype": c, "options": d} for a, b, c, d in flt],
            "roles": [{"role": r} for r in REPORT_ROLES],
        })
    return out


def read(*parts):
    with open(os.path.join(HERE, *parts)) as fh:
        text = fh.read()
    # "# @include name" pulls in include/name.py (shared helpers; Server Scripts cannot import)
    out = []
    for line in text.split("\n"):
        if line.startswith("# @include "):
            with open(os.path.join(HERE, "include", line.split()[-1] + ".py")) as inc:
                out.append(inc.read().rstrip("\n"))
        else:
            out.append(line)
    return "\n".join(out)


def records():
    out = []
    for lib in LIBS:
        out.append({"name": f"SIO lib {lib}", "script_type": "API", "api_method": f"sio_connect.lib.{lib}",
                    "allow_guest": 0, "script": read("lib", f"{lib}.py")})
    for f, (method, rl) in GUEST_API.items():
        r = {"name": f"SIO API {f}", "script_type": "API", "api_method": method, "allow_guest": 1,
             "script": read("api", f"{f}.py")}
        if rl:
            r.update({"enable_rate_limit": 1, "rate_limit_count": rl[0], "rate_limit_seconds": rl[1]})
        out.append(r)
    for f, method in API.items():
        out.append({"name": f"SIO API {f}", "script_type": "API", "api_method": method, "allow_guest": 0,
                    "script": PRELUDE + read("api", f"{f}.py")})
    for name, doctype, event, f in EVENTS:
        out.append({"name": name, "script_type": "DocType Event", "reference_doctype": doctype,
                    "doctype_event": event, "script": read("events", f"{f}.py")})
    for r in out:
        r["module"] = "SIO Connect"
    return out


if __name__ == "__main__":
    dist = os.path.join(HERE, "dist")
    os.makedirs(dist, exist_ok=True)
    recs = records()
    for r in recs:
        with open(os.path.join(dist, r["name"].replace(" ", "_") + ".json"), "w") as fh:
            json.dump(r, fh, indent=1)
    # one bundle for the "SIO deployer" script (Note "SIO deploy" + commit id): every script incl. permission queries
    bundle = [{k: r.get(k) for k in ("name", "script_type", "api_method", "reference_doctype", "doctype_event",
                                     "allow_guest", "module", "script", "enable_rate_limit", "rate_limit_count",
                                     "rate_limit_seconds") if r.get(k) is not None} for r in recs]
    for f, (dt, label) in PQ.items():
        bundle.append({"name": f"SIO {label} unit scope", "script_type": "Permission Query", "reference_doctype": dt,
                       "module": "SIO Connect", "script": read("permission", f + ".py")})
    bundle.append({"name": "SIO task reminders", "script_type": "Scheduler Event", "event_frequency": "Cron",
                   "cron_format": "0 8 * * *", "module": "SIO Connect", "script": read("events", "task_reminders.py")})
    bundle.append({"name": "SIO streak reminders", "script_type": "Scheduler Event", "event_frequency": "Cron",
                   "cron_format": "30 19 * * *", "module": "SIO Connect", "script": read("events", "streak_reminders.py")})
    with open(os.path.join(HERE, "bundle.json"), "w") as fh:
        json.dump(bundle, fh, indent=0)
    print(len(recs), "server scripts")
    for r in reports():
        with open(os.path.join(dist, "report_" + r["report_name"].replace(" ", "_") + ".json"), "w") as fh:
            json.dump(r, fh, indent=1)
    print(len(reports()), "reports")
