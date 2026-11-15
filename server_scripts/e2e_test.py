"""End-to-end test of the SIO API on a live site, as three people.

    python3 server_scripts/e2e_test.py https://siootp.hipersignerp.cloud PASSWORD

Uses sio.test.president@example.com (Unit President) and sio.test.finance@example.com (Finance) in unit
Feroke, and registers a fresh associate each run (so it can be run again): the president approves the
associate, schedules and marks a meeting and sends an update; the new member RSVPs, registers for an
event, gives an offer, records collections in Ramadan Collection 1448 and Baithul Mal 2026-27 and
claims an expense; finance approves it. Totals are checked as differences, so existing data is fine.
Also checks that people are refused what their role does not allow.
"""

import http.cookiejar
import json
import random
import sys
import time
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


RAMADAN, BAITHUL_MAL = "Ramadan Collection 1448", "Baithul Mal 2026-27"
# the test units are kept inactive on the live site; switch them on for the run, off again at the end
adm0 = Client("sio.test.admin@example.com").login()
for u in ("Feroke", "Kalamassery"):
    adm0.m("save_unit", name=u, active=1)
import atexit
atexit.register(lambda: [adm0.m("save_unit", name=u, active=0) for u in ("Feroke", "Kalamassery")])
pres = Client("sio.test.president@example.com").login()
fin = Client("sio.test.finance@example.com").login()
kpres = Client("sio.test.kpres@example.com").login()  # Unit President of Kalamassery
TODAY = date.today().isoformat()
MONTH = (date.today().replace(day=1).isoformat(), TODAY)


def accounts(client, **a):
    return msg(client.m("accounts", from_date=MONTH[0], to_date=TODAY, **a)) or {}


def unit_row(client, unit):
    c = msg(client.m("collection", collection=RAMADAN)) or {}
    return next((u for u in c.get("units", []) if u["unit"] == unit), None), c


acc_before = accounts(fin)
acc_bm_before = accounts(fin, collection=BAITHUL_MAL)
fer_before, _ = unit_row(fin, "Feroke")

stamp = str(int(time.time()))
assoc_email = f"sio.test.a{stamp}@example.com"
code, body = Client("Guest").post(
    "sio_connect.api.auth.register", full_name=f"Test Associate {stamp[-4:]}",
    mobile="9" + "".join(random.choice("0123456789") for _ in range(9)), email=assoc_email, password=PASSWORD,
    unit="Feroke", campus="Farook College", course="BSc Physics", year_of_study="2nd Year")
assert code == 200, (code, body)
assoc_member = body["message"]["member"]
assoc = Client(assoc_email).login()

def totals(client, collection):
    return (msg(client.m("collection", collection=collection)) or {}).get("totals") or {}

def event_counts():
    e = msg(pres.m("event", name="EVT-00001")) or {}
    return e.get("registered_count", 0), float(e.get("spent") or 0)

ram_before = totals(pres, RAMADAN)
bm_before = totals(pres, BAITHUL_MAL)
reg_before, spent_before = event_counts()

print("Roles and capabilities")
p_me, f_me, a_me = msg(pres.m("me")), msg(fin.m("me")), msg(assoc.m("me"))
check("president is Unit President, can mark attendance and approve members",
      p_me["member_role"] == "Unit President" and p_me["capabilities"]["mark_attendance"]
      and p_me["capabilities"]["approve_members"] and not p_me["capabilities"]["approve_expense"], p_me)
check("finance can approve expenses, sees all units, cannot mark attendance",
      f_me["capabilities"]["approve_expense"] and f_me["capabilities"]["all_units"]
      and not f_me["capabilities"]["mark_attendance"], f_me)
check("associate (pending) can give an offer and register, nothing else",
      a_me["status"] == "Pending Approval" and a_me["capabilities"]["offer"]
      and not a_me["capabilities"]["collect"] and not a_me["capabilities"]["view_members"], a_me)

print("Refusals")
r = assoc.m("members")
check("associate cannot list members", r[0] == 403, r)
r = assoc.m("add_collection_entry", collection=RAMADAN, entry_type="Offer", contributor_name="X", offered_amount=100)
check("associate cannot record collections for others", r[0] == 403, r)
r = pres.m("set_expense_status", name="nothing", status="Approved")
check("unit president cannot approve expenses", r[0] == 403, r)
r = pres.m("send_notice", title="t", message="m", audience="Everyone")
check("unit president cannot send to everyone", r[0] == 403, r)

print("Associate before approval")
c = msg(assoc.m("collection"))
names = [x["name"] for x in (c or {}).get("collections", [])]
check("associate sees both open collections", RAMADAN in names and BAITHUL_MAL in names, names)
r = assoc.m("add_collection_entry", collection=RAMADAN, entry_type="Offer", for_self=1, offered_amount=5000)
check("associate gives own offer", r[0] == 200 and msg(r)["status"] == "Offered", r)
r = assoc.m("register_event", event="EVT-00001")
check("associate registers for event", r[0] == 200 and msg(r)["registered"], r)

print("President approves and runs the unit")
r = pres.m("members", status="Pending Approval")
pending = [x["name"] for x in (msg(r) or [])]
check("president sees the pending associate", assoc_member in pending, r)
r = pres.m("approve_member", name=assoc_member, action="approve", member_role="Member")
check("president approves associate as Member", r[0] == 200 and msg(r)["status"] == "Active", r)
r = pres.m("approve_member", name=assoc_member, action="approve", member_role="District Admin")
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
r = assoc.m("add_collection_entry", collection=BAITHUL_MAL, entry_type="Payment", contributor_name="Abdul Gafoor T",
            contributor_type="Well-wisher", paid_amount=2000, payment_mode="UPI")
check("member records a Baithul Mal payment", r[0] == 200 and msg(r)["status"] == "Paid", r)
r = assoc.m("add_collection_entry", collection=RAMADAN, entry_type="Offer", contributor_name="Al-Huda Traders",
            contributor_type="Business", offered_amount=10000, paid_amount=4000, payment_mode="Cash")
check("member records an offer, part paid", r[0] == 200 and msg(r)["status"] == "Part Paid", r)
entry = (msg(r) or {}).get("name")
r = assoc.m("add_payment", entry=entry, amount=6000, mode="UPI")
check("member adds the rest; offer becomes Paid", r[0] == 200 and msg(r)["status"] == "Paid", r)
r = assoc.m("add_collection_entry", collection=RAMADAN, entry_type="Items", contributor_name="Kozhikode Traders",
            items_given="20 food kits", items_value=16000)
check("member records items", r[0] == 200 and msg(r)["status"] == "Items Received", r)
r = assoc.m("claim_expense", description="Posters for Campus Dialogue", amount=1200, category="Printing",
            event="EVT-00001")
check("member claims an expense", r[0] == 200, r)
claim = (msg(r) or {}).get("name")
c = msg(assoc.m("collection", collection=RAMADAN))
check("member sees own offer and what they collected in Ramadan",
      c and len(c["my_offers"]) == 1 and c["my_offers"][0]["status"] == "Offered"
      and c["totals"]["scope"] == "collected_by_me" and c["totals"]["collected"] == 10000
      and c["totals"]["items"] == 16000, c and c.get("totals"))

print("President marks attendance and sends an update")
d = msg(pres.m("meeting", name=meeting))
roster = [x["member"] for x in d.get("roster", [])]
check("roster lists active unit members", assoc_member in roster and "SIO-MEM-00002" in roster, d)
r = pres.m("save_attendance", name=meeting, present=[assoc_member, "SIO-MEM-00002"], minutes="Discussed the dialogue.")
check("attendance saved", r[0] == 200 and msg(r)["present"] == 2, r)
r = pres.m("send_notice", title="Volunteers meet Saturday", message="Campus Dialogue volunteers meet at 4 pm.",
           audience="Unit")
check("unit update sent", r[0] == 200 and msg(r)["recipients"] >= 2, r)
n = msg(assoc.m("notices"))
check("member receives the unit update", n and any(x["title"] == "Volunteers meet Saturday" for x in n), n)
ram, bm = totals(pres, RAMADAN), totals(pres, BAITHUL_MAL)
check("president's Ramadan totals: +15,000 offered, +10,000 received, +16,000 items",
      ram.get("offered", 0) - ram_before.get("offered", 0) == 15000
      and ram.get("collected", 0) - ram_before.get("collected", 0) == 10000
      and ram.get("items", 0) - ram_before.get("items", 0) == 16000 and "scope" not in ram, (ram_before, ram))
check("president's Baithul Mal totals: +2,000 received", bm.get("collected", 0) - bm_before.get("collected", 0) == 2000,
      (bm_before, bm))

print("Finance approves")
e = msg(fin.m("expenses"))
check("finance sees the pending claim", e and any(x["name"] == claim and x["status"] == "Pending" for x in e["claims"]), e)
r = fin.m("set_expense_status", name=claim, status="Approved")
check("finance approves", r[0] == 200 and msg(r)["status"] == "Approved", r)
r = fin.m("set_expense_status", name=claim, status="Paid", payment_mode="UPI")
check("finance marks paid", r[0] == 200 and msg(r)["status"] == "Paid", r)
reg_after, spent_after = event_counts()
check("event: +1 registered, +1,200 approved spend",
      reg_after - reg_before == 1 and spent_after - spent_before == 1200, (reg_before, spent_before, reg_after, spent_after))

print("Units, targets and accounts")
fer, c = unit_row(pres, "Feroke")
check("president sees only Feroke's progress, with its target",
      [u["unit"] for u in c.get("units", [])] == ["Feroke"] and fer and fer["target"] > 0, c.get("units"))
fer_f, c = unit_row(fin, "Feroke")
check("finance sees every unit's progress", len(c.get("units", [])) >= 4, c.get("units"))
check("Feroke progress: +10,000 received", fer_f["collected"] - fer_before["collected"] == 10000, (fer_before, fer_f))
k, c = unit_row(kpres, "Kalamassery")
check("Kalamassery president sees only Kalamassery", [u["unit"] for u in c.get("units", [])] == ["Kalamassery"],
      c.get("units"))
r = kpres.m("members")
check("Kalamassery president does not see Feroke members",
      r[0] == 200 and assoc_member not in [x["name"] for x in msg(r)], r)
ev = msg(kpres.m("event", name="EVT-00001")) or {}
check("Kalamassery president does not see Feroke's event expenses",
      claim not in [x["name"] for x in ev.get("expenses", [])], ev.get("expenses"))
ev = msg(pres.m("event", name="EVT-00001")) or {}
check("Feroke president sees the event's expenses and summary",
      claim in [x["name"] for x in ev.get("expenses", [])] and ev.get("expense_summary", {}).get("paid", 0) >= 1200,
      ev.get("expense_summary"))
ka = accounts(kpres, unit="Feroke")
check("Kalamassery president's accounts stay on Kalamassery", ka.get("unit") == "Kalamassery", ka.get("unit"))
r = assoc.m("accounts")
check("a member cannot open accounts", r[0] == 403, r)
r = assoc.m("claim_expense", description="Relief kit", amount=800, category="Materials", expense_date=TODAY)
relief = (msg(r) or {}).get("name")
fin.m("set_expense_status", name=relief, status="Approved")
r = fin.m("set_expense_status", name=relief, status="Paid", payment_mode="Cash", paid_from=BAITHUL_MAL)
check("finance pays a claim from the Baithul Mal fund", r[0] == 200 and msg(r)["status"] == "Paid", r)
acc = accounts(fin)
check("accounts: +12,000 in, +2,000 out this month",
      acc["in"] - acc_before["in"] == 12000 and acc["out"] - acc_before["out"] == 2000, (acc_before, acc))
check("accounts: closing = opening + in - out, running balance ends at closing",
      abs(acc["opening"] + acc["in"] - acc["out"] - acc["closing"]) < 0.01
      and (not acc["rows"] or abs(acc["rows"][-1]["balance"] - acc["closing"]) < 0.01), acc)
bm = accounts(fin, collection=BAITHUL_MAL)
check("Baithul Mal fund: +2,000 in, +800 out",
      bm["in"] - acc_bm_before["in"] == 2000 and bm["out"] - acc_bm_before["out"] == 800, (acc_bm_before, bm))
ea = accounts(fin, event="EVT-00001")
check("event filter shows only that event's spending",
      ea["in"] == 0 and all(x["event"] == "EVT-00001" for x in ea["rows"]) and claim in [x["ref"] for x in ea["rows"]],
      ea)

print("Managing from the app")
cname = "Test Fund " + stamp[-5:]
r = fin.m("save_collection", collection_name=cname, collection_type="Relief Fund", target_amount=100000,
          unit_targets=json.dumps([{"unit": "Feroke", "target": 40000}, {"unit": "Areekode", "target": 60000}]))
check("finance adds a collection with unit targets", r[0] == 200 and msg(r)["unit_targets_total"] == 100000, r)
r = fin.m("save_collection", name=cname, collection_type="Relief Fund", target_amount=100000, is_active=0,
          unit_targets=json.dumps([{"unit": "Feroke", "target": 50000}, {"unit": "Areekode", "target": 50000}]))
form = msg(fin.m("collection_form", name=cname)) or {}
check("finance edits targets and closes it",
      r[0] == 200 and form["collection"]["is_active"] == 0 and len(form["collection"]["unit_targets"]) == 2, form)
r = pres.m("save_collection", collection_name="Not allowed")
check("unit president cannot add collections", r[0] == 403, r)
r = fin.m("delete_collection", name=RAMADAN)
check("a collection with entries cannot be deleted", r[0] != 200, r)
r = fin.m("delete_collection", name=cname)
check("an empty collection is deleted", r[0] == 200, r)
r = pres.m("save_event", title="Unit meetup " + stamp[-4:], starts_on="2030-01-05 17:00:00", budget=3000, unit="Areekode")
ev_name = (msg(r) or {}).get("name")
ev = [x for x in (msg(pres.m("events")) or []) if x["name"] == ev_name]
check("president adds an event, kept in their own unit", ev and ev[0]["unit"] == "Feroke", ev)
r = kpres.m("save_event", name=ev_name, title="Hijack", starts_on="2030-01-05 17:00:00")
check("another unit's president cannot change it", r[0] == 403, r)
r = pres.m("delete_event", name=ev_name)
check("president deletes the empty event", r[0] == 200, r)
mob = "97" + stamp[-8:]
r = pres.m("save_member", full_name="Added Student " + stamp[-4:], mobile=mob, campus="Farook College")
added = (msg(r) or {}).get("name")
check("president adds a student directly (Active)", r[0] == 200 and msg(r)["status"] == "Active", r)
r = pres.m("save_member", name=added, full_name="Added Student", mobile=mob, member_role="Unit President")
check("president cannot make them Unit President", r[0] == 403, r)
em = "sio.test.s" + stamp + "@example.com"
code, body = Client("Guest").post("sio_connect.api.auth.register", full_name="Added Student", mobile=mob, email=em,
                                  password=PASSWORD, unit="Feroke")
check("student signs up later with the same mobile and gets the same record",
      code == 200 and body["message"]["member"] == added and body["message"]["status"] == "Active", body)

print("Units, picking the unit, and the donor list")
adm = Client("sio.test.admin@example.com").login()
uname = "Test Unit " + stamp[-4:]
r = adm.m("save_unit", unit_name=uname, area="Test campus")
check("district admin adds a unit", r[0] == 200, r)
r = pres.m("save_unit", unit_name="Not allowed " + stamp[-4:])
check("unit president cannot add units", r[0] == 403, r)
units = msg(pres.m("manage_units")) or []
check("everyone sees the unit list with member counts",
      any(u["name"] == uname for u in units) and all("members" in u for u in units), units[:2])
r = adm.m("save_unit", name=uname, active=0)
check("district admin can deactivate a unit", r[0] == 200, r)
donor_mobile = "96" + stamp[-8:]
r = fin.m("add_collection_entry", collection=RAMADAN, entry_type="Payment", contributor_name="Donor " + stamp[-4:],
          contributor_mobile=donor_mobile, contributor_place="Kondotty", paid_amount=1500, unit="Kalamassery")
check("finance records money for a unit they pick", r[0] == 200, r)
entry_unit = (msg(kpres.m("collection", collection=RAMADAN)) or {}).get("entries") or []
check("it counts for Kalamassery and its president sees it",
      any(e["contributor_mobile"] == donor_mobile and e["unit"] == "Kalamassery" for e in entry_unit), entry_unit[:2])
r = pres.m("add_collection_entry", collection=RAMADAN, entry_type="Payment", contributor_name="X", paid_amount=10,
           unit="Kalamassery", contributor_mobile="95" + stamp[-8:])
x = [e for e in ((msg(pres.m("collection", collection=RAMADAN)) or {}).get("entries") or []) if e["contributor_name"] == "X"]
check("a unit president's entry always counts for their own unit", r[0] == 200 and x and x[0]["unit"] == "Feroke", x)
r = fin.m("add_collection_entry", collection=BAITHUL_MAL, entry_type="Offer", contributor_name="Donor " + stamp[-4:],
          contributor_mobile="+91 " + donor_mobile, offered_amount=2000, unit="Kalamassery")
d = msg(fin.m("donors", q=donor_mobile)) or {}
one = [x for x in d.get("donors", []) if x["key"] == donor_mobile]
check("donor list joins the same person by mobile across collections",
      one and one[0]["times"] == 2 and one[0]["given"] == 1500 and one[0]["balance"] == 2000
      and one[0]["offered"] == 2000      and one[0]["place"] == "Kondotty", one)
d = msg(kpres.m("donors", collection=RAMADAN, show="not_yet")) or {}
check("'not given this time' leaves out people who gave in Ramadan",
      all(x["key"] != donor_mobile for x in d.get("donors", [])), d.get("count"))
d = msg(kpres.m("donors", show="to_pay")) or {}
check("'still to pay' lists the open offer", any(x["key"] == donor_mobile for x in d.get("donors", [])), d.get("count"))
d = msg(pres.m("donors", q=donor_mobile)) or {}
check("Feroke president does not see Kalamassery's donor", not [x for x in d.get("donors", []) if x["key"] == donor_mobile
                                                                and x["unit"] == "Kalamassery"], d)
r = assoc.m("donors")
check("a member sees only the people they collected from",
      r[0] == 200 and all(x["name"] in ("Abdul Gafoor T", "Al-Huda Traders", "Kozhikode Traders") for x in msg(r)["donors"]),
      msg(r))

print("Adding donors before they give")
new_mobile = "93" + stamp[-8:]
r = pres.m("save_donor", donor_name="Haji Test " + stamp[-4:], mobile=new_mobile, place="Feroke town",
           notes="gives every Ramadan", unit="Kalamassery")
donor_id = (msg(r) or {}).get("name")
check("president adds a donor (kept in their own unit)", r[0] == 200, r)
d = msg(pres.m("donors", q=new_mobile)) or {}
one = [x for x in d.get("donors", []) if x["key"] == new_mobile]
check("the new donor shows in the list with nothing given yet",
      one and one[0]["given"] == 0 and one[0]["unit"] == "Feroke" and one[0]["notes"] == "gives every Ramadan", one)
d = msg(pres.m("donors", collection=RAMADAN, show="not_yet")) or {}
check("and in 'not given yet'", any(x["key"] == new_mobile for x in d.get("donors", [])), d.get("count"))
r = pres.m("save_donor", donor_name="Someone Else", mobile="+91 " + new_mobile)
check("the same mobile can't be added twice", r[0] != 200, r)
r = kpres.m("save_donor", name=donor_id, donor_name="Hijack", mobile=new_mobile)
check("another unit can't change this donor", r[0] == 403, r)
pres.m("add_collection_entry", collection=RAMADAN, entry_type="Payment", contributor_name="Haji Test",
       contributor_mobile=new_mobile, paid_amount=500)
d = msg(pres.m("donors", q=new_mobile)) or {}
one = [x for x in d.get("donors", []) if x["key"] == new_mobile]
check("when they give, it joins the same donor line", len(one) == 1 and one[0]["given"] == 500
      and one[0]["name"].startswith("Haji Test "), one)

print("Unit expense approver")
appr = Client("sio.test.assoc1@example.com").login()          # an ordinary Member of Feroke
r = adm.m("save_unit", name="Feroke", active=1, expense_approver="SIO-MEM-00001")
check("area admin makes a member Feroke's expense approver", r[0] == 200, r)
me_appr = msg(appr.m("me")) or {}
check("the approver now can approve expenses", me_appr.get("capabilities", {}).get("approve_expense") is True, me_appr)
r = pres.m("claim_expense", description="Banner printing", amount=700, category="Printing", expense_date=TODAY)
c1 = (msg(r) or {}).get("name")
lst = msg(appr.m("expenses")) or {}
row = [x for x in lst.get("claims", []) if x["name"] == c1]
check("the approver sees Feroke's claims and may act on them", row and row[0]["can_act"], row)
r = appr.m("set_expense_status", name=c1, status="Approved")
check("the approver approves the president's claim", r[0] == 200 and msg(r)["status"] == "Approved", r)
r = appr.m("claim_expense", description="My own tea", amount=90, category="Food", expense_date=TODAY)
c2 = (msg(r) or {}).get("name")
r = appr.m("set_expense_status", name=c2, status="Approved")
check("the approver can't approve their own claim", r[0] == 403, r)
r = kpres.m("claim_expense", description="Kalamassery bill", amount=300, category="Other", expense_date=TODAY)
c3 = (msg(r) or {}).get("name")
r = appr.m("set_expense_status", name=c3, status="Approved")
check("the approver can't approve another unit's claim", r[0] == 403, r)

print("Programme fund requests")
r = assoc.m("request_fund", title="X", purpose="y", amount_requested=100)
check("a member can't ask for programme funds", r[0] == 403, r)
r = pres.m("request_fund", title="Campus quiz " + stamp[-4:], purpose="Prizes, printing and hall",
           amount_requested=5000, breakdown="Prizes 3000, printing 1000, hall 1000", needed_by="2030-01-10")
fr = (msg(r) or {}).get("name")
check("unit president asks the area for 5,000", r[0] == 200 and msg(r)["status"] == "Pending", r)
lst = msg(kpres.m("fund_requests")) or {}
check("another unit doesn't see it", all(x["name"] != fr for x in lst.get("requests", [])), lst.get("counts"))
r = pres.m("set_fund_request", name=fr, action="approve", approved_amount=4000)
check("the unit can't approve its own request", r[0] == 403, r)
acc0 = accounts(fin)
fer0 = accounts(fin, unit="Feroke")
r = fin.m("set_fund_request", name=fr, action="approve", approved_amount=4000, remarks="Hall not needed")
check("finance approves 4,000 of it", r[0] == 200 and msg(r)["status"] == "Approved", r)
acc_mid = accounts(fin)
check("approved-not-released shows in 'to pay' for the area", acc_mid["to_pay"] - acc0["to_pay"] == 4000,
      (acc0["to_pay"], acc_mid["to_pay"]))
r = fin.m("set_fund_request", name=fr, action="release", payment_mode="UPI", paid_from=BAITHUL_MAL)
check("finance releases it from Baithul Mal", r[0] == 200 and msg(r)["status"] == "Released", r)
r = pres.m("claim_expense", description="Quiz prizes", amount=1500, category="Materials", expense_date=TODAY,
           fund_request=fr)
c4 = (msg(r) or {}).get("name")
check("the unit claims 1,500 against the released fund", r[0] == 200, r)
appr.m("set_expense_status", name=c4, status="Approved")
r = appr.m("set_expense_status", name=c4, status="Paid", payment_mode="Cash")
lst = msg(pres.m("fund_requests")) or {}
one = [x for x in lst.get("requests", []) if x["name"] == fr]
check("the fund request shows 4,000 released, 1,500 spent, 2,500 left",
      one and one[0]["released_amount"] == 4000 and one[0]["spent_amount"] == 1500 and one[0]["balance"] == 2500, one)
acc1 = accounts(fin)
check("area accounts: the release is 4,000 out; the unit's spending isn't counted again",
      acc1["out"] - acc0["out"] == 4000, (acc0["out"], acc1["out"]))
fer1 = accounts(fin, unit="Feroke")
check("Feroke's accounts: 4,000 in from the area, 1,500 out",
      fer1["in"] - fer0["in"] == 4000 and fer1["out"] - fer0["out"] == 1500, (fer0, fer1))
r = adm.m("save_unit", name="Feroke", active=1, expense_approver="")
check("approver removed again", r[0] == 200 and not (msg(appr.m("me")) or {}).get("capabilities", {}).get("approve_expense"), r)

print("Desk / REST access is locked to the right people")
code, body = pres.post("frappe.client.rename_doc", doctype="SIO Unit", old_name="Kalamassery", new_name="X")
check("a unit president cannot rename units", code != 200, body)
code, body = adm.post("frappe.client.rename_doc", doctype="SIO Unit", old_name=uname, new_name=uname + " B")
check("an area admin can rename a unit", code == 200, body)

print("Fingerprint sign-in (API key)")
r = assoc.post("sio_connect.api.auth.enable_biometric", device_name="Test phone")
keys = msg(r) or {}
phone = Client(assoc_email)
phone.token = f"{keys.get('api_key')}:{keys.get('api_secret')}"
r = phone.m("me")
check("token sign-in works without a password", r[0] == 200 and msg(r)["member"] == assoc_member, r)
assoc.post("sio_connect.api.auth.disable_biometric")
r = phone.m("me")
check("after turning it off the old token is refused", r[0] in (401, 403), r)

print(f"\n{ok_count} passed, {fail_count} failed")
sys.exit(1 if fail_count else 0)
