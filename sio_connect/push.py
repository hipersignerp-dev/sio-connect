"""Push notifications through Firebase Cloud Messaging (HTTP v1), straight from the server.

The Firebase service account JSON is pasted (by an admin) into SIO Settings > Firebase service account; it is
stored encrypted. Every SIO Notice is pushed to the phones of the members it reaches (see hooks.py). Tokens
come from the phone app (api push_register). Tokens that Firebase reports as gone are deleted.
"""

import json
import time

import frappe
import requests

SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


def _service_account():
	try:
		raw = frappe.get_single("SIO Settings").get_password("firebase_service_account", raise_exception=False)
	except Exception:
		raw = None
	return json.loads(raw) if raw else None


def _access_token(sa):
	key = "sio_fcm_token"
	cached = frappe.cache.get_value(key)
	if cached:
		return cached
	import jwt  # PyJWT ships with Frappe

	now = int(time.time())
	assertion = jwt.encode(
		{"iss": sa["client_email"], "scope": SCOPE, "aud": sa["token_uri"], "iat": now, "exp": now + 3600},
		sa["private_key"],
		algorithm="RS256",
	)
	r = requests.post(
		sa["token_uri"],
		data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion},
		timeout=20,
	)
	r.raise_for_status()
	token = r.json()["access_token"]
	frappe.cache.set_value(key, token, expires_in_sec=3000)
	return token


def send(members, title, body, data=None):
	"""Push to these SIO Members' phones. Runs in the background (see notice_after_insert)."""
	sa = _service_account()
	if not sa or not members:
		return 0
	tokens = frappe.get_all(
		"SIO Push Token", filters={"member": ["in", list(members)]}, fields=["name", "token"], limit=5000
	)
	if not tokens:
		return 0
	access = _access_token(sa)
	url = f"https://fcm.googleapis.com/v1/projects/{sa['project_id']}/messages:send"
	headers = {"Authorization": f"Bearer {access}", "Content-Type": "application/json"}
	sent = 0
	for t in tokens:
		msg = {
			"message": {
				"token": t.token,
				"notification": {"title": title[:120], "body": (body or "")[:400]},
				"data": {k: str(v) for k, v in (data or {}).items()},
				"android": {
					"priority": "high",
					"notification": {"channel_id": "sio_notices", "color": "#1A62A8"},
				},
			}
		}
		try:
			r = requests.post(url, headers=headers, data=json.dumps(msg), timeout=20)
			if r.status_code in (404, 400) and ("UNREGISTERED" in r.text or "INVALID_ARGUMENT" in r.text):
				frappe.delete_doc("SIO Push Token", t.name, ignore_permissions=True, force=True)
			elif r.ok:
				sent += 1
		except Exception:
			frappe.log_error(title="SIO push failed")
	frappe.db.commit()
	return sent


def notice_members(doc):
	"""The members a notice reaches (same rules as the notice_before_insert script)."""
	filters = {"status": ["in", ["Active", "Pending Approval"]]}
	if doc.audience == "Unit":
		filters["unit"] = doc.unit
	elif doc.audience == "Role":
		filters["member_role"] = doc.member_role
	if doc.audience in ("Everyone", "Role") and doc.get("area"):
		filters["area"] = doc.area
	elif doc.audience == "Person":
		filters["name"] = doc.member or "__none__"
	elif doc.audience == "Event Registrants":
		regs = frappe.get_all(
			"SIO Event Registration",
			filters={"event": doc.event, "status": ["!=", "Cancelled"]},
			pluck="member",
		)
		filters["name"] = ["in", regs or ["__none__"]]
	return frappe.get_all("SIO Member", filters=filters, pluck="name", limit=10000)


def on_notice(doc, method=None):
	"""SIO Notice, after insert: push it (in the background, so saving the notice stays fast)."""
	frappe.enqueue(
		"sio_connect.push.push_notice", queue="short", notice=doc.name, enqueue_after_commit=True
	)


def push_notice(notice):
	doc = frappe.get_doc("SIO Notice", notice)
	members = notice_members(doc)
	send(members, doc.title or "SIO Connect", frappe.utils.strip_html(doc.message or ""), {"notice": doc.name})
