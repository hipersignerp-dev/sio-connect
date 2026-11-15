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

'''

LIBS = ["ctx", "events", "notices", "totals", "collections"]

GUEST_API = {
    # file: (method, rate limit (count, seconds) or None)
    "units": ("sio_connect.api.auth.units", None),
    "register": ("sio_connect.api.auth.register", (5, 3600)),
}
API = {
    "enable_biometric": "sio_connect.api.auth.enable_biometric",
    "disable_biometric": "sio_connect.api.auth.disable_biometric",
}
MOBILE = ["me", "update_my_profile", "home", "meetings", "meeting", "rsvp", "save_attendance", "schedule_meeting",
          "events", "event", "register_event", "collection", "add_collection_entry", "add_payment", "expenses",
          "claim_expense", "set_expense_status", "notices", "send_notice", "members", "approve_member"]
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
    ("SIO Notice recipients", "SIO Notice", "Before Insert", "notice_before_insert"),
    ("SIO Notice email", "SIO Notice", "After Insert", "notice_after_insert"),
    ("SIO Device revoke", "SIO Device Token", "After Save", "device_after_save"),
]


def read(*parts):
    with open(os.path.join(HERE, *parts)) as fh:
        return fh.read()


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
    print(len(recs), "server scripts")
