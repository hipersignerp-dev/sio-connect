"""Admin-only checks used while switching a site from Server Scripts to this app."""

import frappe

from sio_connect import runtime


@frappe.whitelist()
def run(method):
	"""Run one of the app's API scripts directly (even while a Server Script of the same path still exists),
	e.g. method="mobile.home", to compare the app's answer with the Server Script's."""
	frappe.only_for(("System Manager", "SIO Admin"))
	mod, fn = method.split(".", 1)
	key = None
	with open(frappe.get_app_path("sio_connect", "api", mod + ".py")) as fh:
		text = fh.read()
	marker = f"def {fn}(**kwargs):\n\tapi(\""
	i = text.find(marker)
	if i >= 0:
		key = text[i + len(marker) :].split('"', 1)[0]
	if not key:
		frappe.throw("Unknown method")
	runtime.api(key)
	return frappe.response.get("message")


@frappe.whitelist()
def push_test():
	"""Send a test push to my own phone(s)."""
	from sio_connect.push import send

	m = frappe.db.get_value("SIO Member", {"user": frappe.session.user}, "name")
	return {"sent": send([m] if m else [], "SIO Connect", "Push notifications are working ✅")}
