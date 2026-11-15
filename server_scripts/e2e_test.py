"""End-to-end test of the SIO API on a live site, as three people.

    python3 server_scripts/e2e_test.py https://siootp.hipersignerp.cloud PASSWORD

Uses the test accounts sio.test.{assoc1,president,finance}@example.com (all in unit Feroke):
the president approves the associate, schedules and marks a meeting, records collections and sends
an update; the new member RSVPs, registers for an event, pledges and claims an expense; finance
approves it. Also checks that people are refused what their role does not allow.
"""

import http.cookiejar
import json
import sys
import urllib.parse
import urllib.request
from datetime import date, timedelta

BASE, PASSWORD = sys.argv[1].rstrip("/"), sys.argv[2]
ok_count = 0
fail_count = 0


class Client:
    def __init__(self, user):
        self.user = user
        self.jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self.jar))
        self.token = None

    def post(self, api_method, **args):
        data = urllib.parse.urlencode(
            {k: (json.dumps(v) if isinstance(v, (list, dict)) else v) for k, v in args.items() if v is not None}
        ).encode()
        req = urllib.request.Request(f"{BASE}/api/method/{api_method}", data=data, method="POST")
        req.add_header("Accept", "application/json")
        if self.token:
            req.add_header("Authorization", f"token {self.token}")
        try:
            with (self.opener if not self.token else urllib.request.build_opener()).open(req, timeout=40) as r:
                return r.status, json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            body = e.read()
            try:
                return e.code, json.loads(body)
            except Exception:
                return e.code, {"raw": body[:300].decode(errors="replace")}

    def login(self):
        code, body = self.post("login", usr=self.user, pwd=PASSWORD, device="mobile")
        assert code == 200, (code, body)
        return self

    def m(self, method, **args):
        return self.post(f"sio_connect.api.mobile.{method}", **args)


def check(label, cond, detail=""):
    global ok_count, fail_count
    if cond:
        ok_count += 1
        print(f"  ok   {label}")
    else:
        fail_count += 1
        print(f"  FAIL {label}  {str(detail)[:400]}")


def msg(resp):
    return resp[1].get("message")


def err(resp):
    b = resp[1]
    sm = b.get("_server_messages")
    if sm:
        try:
            return json.loads(json.loads(sm)[0]).get("message")
        except Exception:
            return sm
    return b.get("exc_type") or b.get("exception") or b


pres = Client("sio.test.president@example.com").login()
fin = Client("sio.test.finance@example.com").login()
assoc = Client("sio.test.assoc1@example.com").login()

print("Roles and capabilities")
p_me, f_me, a_me = msg(pres.m("me")), msg(fin.m("me")), msg(assoc.m("me"))
check("president is Unit President, can mark attendance and approve members",
      p_me["member_role"] == "Unit President" and p_me["capabilities"]["mark_attendance"]
      and p_me["capabilities"]["approve_members"] and not p_me["capabilities"]["approve_expense"], p_me)
check("finance can approve expenses, sees all units, cannot mark attendance",
      f_me["capabilities"]["approve_expense"] and f_me["capabilities"]["all_units"]
      and not f_me["capabilities"]["mark_attendance"], f_me)
check("associate (pending) can pledge and register, nothing else",
      a_me["status"] == "Pending Approval" and a_me["capabilities"]["pledge"]
      and not a_me["capabilities"]["collect"] and not a_me["capabilities"]["view_members"], a_me)

print("Refusals")
r = assoc.m("members")
check("associate cannot list members", r[0] == 403, r)
r = assoc.m("add_collection_entry", entry_type="Pledge", contributor_name="X", pledged_amount=100)
check("associate cannot record collections for others", r[0] == 403, r)
r = pres.m("set_expense_status", name="nothing", status="Approved")
check("unit president cannot approve expenses", r[0] == 403, r)
r = pres.m("send_notice", title="t", message="m", audience="Everyone")
check("unit president cannot send to everyone", r[0] == 403, r)

print("Associate before approval")
r = assoc.m("add_collection_entry", entry_type="Pledge", for_self=1, pledged_amount=5000)
check("associate makes own pledge", r[0] == 200 and msg(r)["status"] == "Pledged", r)
r = assoc.m("register_event", event="EVT-00001")
check("associate registers for event", r[0] == 200 and msg(r)["registered"], r)

print("President approves and runs the unit")
r = pres.m("members", status="Pending Approval")
pending = [x["name"] for x in (msg(r) or [])]
check("president sees the pending associate", "SIO-MEM-00001" in pending, r)
r = pres.m("approve_member", name="SIO-MEM-00001", action="approve", member_role="Member")
check("president approves associate as Member", r[0] == 200 and msg(r)["status"] == "Active", r)
r = pres.m("approve_member", name="SIO-MEM-00001", action="approve", member_role="District Admin")
check("president cannot make someone District Admin", r[0] == 403, r)
a_me = msg(assoc.m("me"))
check("approved member now can RSVP, collect and claim",
      a_me["status"] == "Active" and a_me["capabilities"]["rsvp"] and a_me["capabilities"]["collect"]
      and a_me["capabilities"]["claim_expense"], a_me)

friday = (date.today() + timedelta(days=(4 - date.today().weekday()) % 7 or 7)).isoformat()
r = pres.m("schedule_meeting", topic="Study circle: Surah Al-Asr", meeting_date=friday, meeting_time="19:30:00",
           venue="Unit office, Feroke")
check("president schedules a meeting", r[0] == 200, r)
meeting = (msg(r) or {}).get("name")

print("Member's day")
h = msg(assoc.m("home"))
check("home shows the next meeting and event",
      h and h["next_meeting"] and h["next_meeting"]["name"] == meeting and h["next_event"], h)
r = assoc.m("rsvp", name=meeting, attending=1)
check("member RSVPs", r[0] == 200 and msg(r)["rsvp"] == "Attending", r)
r = assoc.m("add_collection_entry", entry_type="Payment", contributor_name="Abdul Gafoor T",
            contributor_type="Well-wisher", paid_amount=2000, payment_mode="UPI")
check("member records a payment collected", r[0] == 200 and msg(r)["status"] == "Paid", r)
r = assoc.m("add_collection_entry", entry_type="Pledge", contributor_name="Al-Huda Traders",
            contributor_type="Business", pledged_amount=10000, paid_amount=4000, payment_mode="Cash")
check("member records a part-paid pledge", r[0] == 200 and msg(r)["status"] == "Part Paid", r)
entry = (msg(r) or {}).get("name")
r = assoc.m("add_payment", entry=entry, amount=6000, mode="UPI")
check("member adds the rest; pledge becomes Paid", r[0] == 200 and msg(r)["status"] == "Paid", r)
r = assoc.m("claim_expense", description="Posters for Campus Dialogue", amount=1200, category="Printing",
            event="EVT-00001")
check("member claims an expense", r[0] == 200, r)
claim = (msg(r) or {}).get("name")
c = msg(assoc.m("collection"))
check("member sees own pledge and what they collected",
      c and len(c["my_pledges"]) == 1 and c["totals"]["scope"] == "collected_by_me"
      and c["totals"]["collected"] == 12000, c and c.get("totals"))

print("President marks attendance and sends an update")
d = msg(pres.m("meeting", name=meeting))
roster = [x["member"] for x in d.get("roster", [])]
check("roster lists active unit members", "SIO-MEM-00001" in roster and "SIO-MEM-00002" in roster, d)
r = pres.m("save_attendance", name=meeting, present=["SIO-MEM-00001", "SIO-MEM-00002"], minutes="Discussed the dialogue.")
check("attendance saved", r[0] == 200 and msg(r)["present"] == 2, r)
r = pres.m("send_notice", title="Volunteers meet Saturday", message="Campus Dialogue volunteers meet at 4 pm.",
           audience="Unit")
check("unit update sent", r[0] == 200 and msg(r)["recipients"] >= 2, r)
n = msg(assoc.m("notices"))
check("member receives the unit update", n and any(x["title"] == "Volunteers meet Saturday" for x in n), n)
c = msg(pres.m("collection"))
check("president sees unit collection totals", c and c["totals"]["collected"] == 12000 and "scope" not in c["totals"],
      c and c.get("totals"))

print("Finance approves")
e = msg(fin.m("expenses"))
check("finance sees the pending claim", e and any(x["name"] == claim and x["status"] == "Pending" for x in e["claims"]), e)
r = fin.m("set_expense_status", name=claim, status="Approved")
check("finance approves", r[0] == 200 and msg(r)["status"] == "Approved", r)
r = fin.m("set_expense_status", name=claim, status="Paid", payment_mode="UPI")
check("finance marks paid", r[0] == 200 and msg(r)["status"] == "Paid", r)
ev = msg(pres.m("event", name="EVT-00001"))
check("event shows 1 registered and approved spend 1200",
      ev and ev["registered_count"] == 1 and float(ev["spent"]) == 1200, ev)

print("Fingerprint sign-in (API key)")
r = assoc.post("sio_connect.api.auth.enable_biometric", device_name="Test phone")
keys = msg(r) or {}
phone = Client("sio.test.assoc1@example.com")
phone.token = f"{keys.get('api_key')}:{keys.get('api_secret')}"
r = phone.m("me")
check("token sign-in works without a password", r[0] == 200 and msg(r)["member"] == "SIO-MEM-00001", r)
assoc.post("sio_connect.api.auth.disable_biometric")
r = phone.m("me")
check("after turning it off the old token is refused", r[0] in (401, 403), r)

print(f"\n{ok_count} passed, {fail_count} failed")
sys.exit(1 if fail_count else 0)
