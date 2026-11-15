"""Sign-up and fingerprint sign-in for the SIO phone app.

Password sign-in uses Frappe's own /api/method/login (device=mobile).
Fingerprint sign-in: after a password sign-in the app calls enable_biometric(), which returns the
user's API key and a fresh secret. The phone keeps them in its secure storage and releases them only
after the fingerprint/face check, then sends them as a token. The same flow works on a site set up
with server scripts only (see server_scripts/). Tick Revoked on a phone's SIO Device Token record to
block it: the secret is replaced.
"""

import hashlib
import re

import frappe
from frappe import _
from frappe.rate_limiter import rate_limit
from frappe.utils import now_datetime, validate_email_address

from sio_connect.utils import ROLE_ASSOCIATE

def _hash(token):
	return hashlib.sha256((token or "").encode()).hexdigest()


@frappe.whitelist(allow_guest=True)
def units():
	"""Units to pick from on the sign-up screen."""
	return frappe.get_all(
		"SIO Unit", filters={"active": 1}, fields=["name", "district"], order_by="district asc, name asc"
	)


@frappe.whitelist(allow_guest=True, methods=["POST"])
@rate_limit(limit=5, seconds=60 * 60)
def register(full_name, mobile, email, password, unit=None, campus=None, course=None, year_of_study=None,
             home_town=None):
	"""Self sign-up as an Associate. The unit admin approves the member later."""
	full_name = (full_name or "").strip()
	mobile = re.sub(r"[^\d+]", "", mobile or "")
	email = (email or "").strip().lower()
	if len(full_name) < 3:
		frappe.throw(_("Enter your full name."))
	if len(re.sub(r"\D", "", mobile)) < 10:
		frappe.throw(_("Enter a valid mobile number."))
	if not validate_email_address(email):
		frappe.throw(_("Enter a valid email address."))
	if len(password or "") < 8:
		frappe.throw(_("Password must be at least 8 characters."))
	if unit and not frappe.db.exists("SIO Unit", {"name": unit, "active": 1}):
		frappe.throw(_("Pick your unit from the list."))
	if frappe.db.exists("User", email) or frappe.db.exists("SIO Member", {"mobile": mobile}):
		frappe.throw(_("This email or mobile is already registered. Sign in, or use Forgot password."))

	parts = full_name.split(" ", 1)
	user = frappe.get_doc(
		{
			"doctype": "User",
			"email": email,
			"first_name": parts[0],
			"last_name": parts[1] if len(parts) > 1 else "",
			"mobile_no": mobile,
			"enabled": 1,
			"send_welcome_email": 0,
			"user_type": "Website User",
			"new_password": password,
			"roles": [{"role": ROLE_ASSOCIATE}],
		}
	)
	user.flags.ignore_permissions = True
	user.flags.no_welcome_mail = True
	user.insert()

	member = frappe.get_doc(
		{
			"doctype": "SIO Member",
			"full_name": full_name,
			"mobile": mobile,
			"email": email,
			"user": user.name,
			"member_role": "Associate",
			"status": "Pending Approval",
			"unit": unit,
			"campus": campus,
			"course": course,
			"year_of_study": year_of_study or "",
			"home_town": home_town,
		}
	)
	member.insert(ignore_permissions=True)
	return {"user": user.name, "member": member.name, "status": member.status}


@frappe.whitelist(methods=["POST"])
def enable_biometric(device_name=None):
	"""Called right after a password sign-in when the person turns on fingerprint sign-in.
	Returns the user's API key and a new secret; the phone keeps them behind the fingerprint and sends
	them as `Authorization: token key:secret`. One secret per user: a new phone replaces the old one."""
	user = frappe.session.user
	if user == "Guest":
		frappe.throw(_("Please sign in."), frappe.AuthenticationError)
	u = frappe.get_doc("User", user)
	if not u.api_key:
		u.api_key = frappe.generate_hash(length=15)
	secret = frappe.generate_hash(length=15)
	u.api_secret = secret
	u.save(ignore_permissions=True)
	for name in frappe.get_all("SIO Device Token", filters={"user": user, "revoked": 0}, pluck="name"):
		frappe.db.set_value("SIO Device Token", name, "revoked", 1)
	frappe.get_doc(
		{
			"doctype": "SIO Device Token",
			"user": user,
			"device_name": (device_name or "Phone")[:140],
			"token_hash": _hash(secret),
			"last_used": now_datetime(),
		}
	).insert(ignore_permissions=True)
	return {"api_key": u.api_key, "api_secret": secret}


def replace_secret(user):
	"""Stops fingerprint sign-in for the user: the phone's copy of the secret no longer works."""
	u = frappe.get_doc("User", user)
	if u.api_key:
		u.api_secret = frappe.generate_hash(length=15)
		u.save(ignore_permissions=True)


@frappe.whitelist(methods=["POST"])
def disable_biometric():
	"""Turn off fingerprint sign-in for this account."""
	replace_secret(frappe.session.user)
	for name in frappe.get_all("SIO Device Token", filters={"user": frappe.session.user, "revoked": 0}, pluck="name"):
		frappe.db.set_value("SIO Device Token", name, "revoked", 1)
	return {"ok": True}
