"""Sign-up and fingerprint sign-in for the SIO phone app.

Password sign-in uses Frappe's own /api/method/login (device=mobile).
Fingerprint sign-in: after a password sign-in the app calls enable_biometric(), which returns a
long random device token. Only its SHA-256 hash is kept in ERP (SIO Device Token). The phone keeps
the token in its secure storage and releases it only after the fingerprint/face check, then calls
login_with_device() to get a fresh session. Revoke a phone by ticking Revoked on its record.
"""

import hashlib
import re
import secrets

import frappe
from frappe import _
from frappe.rate_limiter import rate_limit
from frappe.utils import cint, now_datetime, validate_email_address

from sio_connect.utils import ROLE_ASSOCIATE

MAX_PHONES_PER_USER = 5


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
	"""Called right after a password sign-in when the person turns on fingerprint sign-in."""
	user = frappe.session.user
	if user == "Guest":
		frappe.throw(_("Please sign in."), frappe.AuthenticationError)
	token = secrets.token_urlsafe(40)
	frappe.get_doc(
		{
			"doctype": "SIO Device Token",
			"user": user,
			"device_name": (device_name or "Phone")[:140],
			"token_hash": _hash(token),
			"last_used": now_datetime(),
		}
	).insert(ignore_permissions=True)
	# keep only the newest phones
	old = frappe.get_all(
		"SIO Device Token", filters={"user": user, "revoked": 0}, order_by="creation desc", pluck="name"
	)[MAX_PHONES_PER_USER:]
	for name in old:
		frappe.db.set_value("SIO Device Token", name, "revoked", 1)
	return {"token": token}


@frappe.whitelist(allow_guest=True, methods=["POST"])
@rate_limit(limit=20, seconds=60 * 10)
def login_with_device(token):
	"""Fingerprint sign-in: trade the phone's device token for a new session."""
	row = frappe.db.get_value(
		"SIO Device Token", {"token_hash": _hash(token), "revoked": 0}, ["name", "user"], as_dict=True
	)
	if not row or not cint(frappe.db.get_value("User", row.user, "enabled")):
		frappe.local.response["http_status_code"] = 401
		frappe.throw(_("Fingerprint sign-in is no longer active on this phone. Sign in with your password."),
		             frappe.AuthenticationError)
	frappe.db.set_value("SIO Device Token", row.name, "last_used", now_datetime(), update_modified=False)
	frappe.local.login_manager.login_as(row.user)
	return {"sid": frappe.session.sid, "user": row.user}


@frappe.whitelist(methods=["POST"])
def disable_biometric(token=None):
	"""Stop fingerprint sign-in on this phone (or all of the user's phones when no token is given)."""
	filters = {"user": frappe.session.user, "revoked": 0}
	if token:
		filters["token_hash"] = _hash(token)
	for name in frappe.get_all("SIO Device Token", filters=filters, pluck="name"):
		frappe.db.set_value("SIO Device Token", name, "revoked", 1)
	return {"ok": True}
