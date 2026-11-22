"""Runs the SIO Connect scripts that ship with this app (sio_connect/scripts/*.py).

They are the same scripts the site used to run as Server Scripts (built by server_scripts/build.py), and they
run the same way: through Frappe's safe_exec, with run_script() reading the app's own copy of the library
scripts. Until SIO Settings > "use_app_code" is ticked, the document events, scheduled jobs and permission
queries here do nothing, so a site that still runs the Server Scripts never runs anything twice. Whitelisted
API methods are always available (an enabled API Server Script with the same name takes priority).
"""

import os
from functools import lru_cache

import frappe
from frappe.utils.safe_exec import call_with_form_dict, safe_exec

from sio_connect._registry import LIBS

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts")


@lru_cache(maxsize=512)
def source(key):
	with open(os.path.join(HERE, key + ".py")) as fh:
		return fh.read()


def _run_script(name, **kwargs):
	# "SIO lib ctx" -> the app's copy of that library script; returns its frappe.flags like run_script() does
	key = LIBS.get(name)
	if not key:
		frappe.throw(f"Unknown script {name}")
	return call_with_form_dict(lambda: _exec(key)[0].frappe.flags, kwargs)


def _exec(key, _locals=None, restrict=False):
	return safe_exec(
		source(key),
		_globals={"run_script": _run_script},
		_locals=_locals,
		restrict_commit_rollback=restrict,
		script_filename=key,
	)


def app_code_on():
	if frappe.flags.sio_app_code is None:
		try:
			frappe.flags.sio_app_code = bool(frappe.db.get_single_value("SIO Settings", "use_app_code"))
		except Exception:
			frappe.flags.sio_app_code = False
	return frappe.flags.sio_app_code


def api(key, guest=False):
	if frappe.session.user == "Guest" and not guest:
		raise frappe.PermissionError
	_exec(key)
	# the script put its answer in frappe.response["message"]


def doc_event(key, doc):
	if app_code_on():
		_exec(key, {"doc": doc}, restrict=True)


def scheduled(key):
	if app_code_on():
		_exec(key)


def permission_query(key, user=None, **kwargs):
	if not app_code_on():
		return ""
	loc = {"user": user or frappe.session.user, "conditions": "", "active_child_tables": []}
	_exec(key, loc)
	return loc["conditions"] or ""
