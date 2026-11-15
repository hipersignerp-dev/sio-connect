import json

import frappe

from sio_connect.utils import ALL_ROLES, DESK_ROLES

WORKSPACE = "SIO Connect"

SHORTCUTS = [
	("Members", "SIO Member", "DocType"),
	("Units", "SIO Unit", "DocType"),
	("Weekly Meetings", "SIO Meeting", "DocType"),
	("Events", "SIO Event", "DocType"),
	("Event Registrations", "SIO Event Registration", "DocType"),
	("Collections", "SIO Collection", "DocType"),
	("Collection Entries", "SIO Collection Entry", "DocType"),
	("Expense Claims", "SIO Expense Claim", "DocType"),
	("Notices", "SIO Notice", "DocType"),
	("Phones (fingerprint login)", "SIO Device Token", "DocType"),
]


def after_install():
	make_roles()
	make_workspace()


def after_migrate():
	make_roles()
	make_workspace()


def make_roles():
	for role in ALL_ROLES:
		desk = 1 if role in DESK_ROLES else 0
		if frappe.db.exists("Role", role):
			frappe.db.set_value("Role", role, "desk_access", desk, update_modified=False)
		else:
			frappe.get_doc({"doctype": "Role", "role_name": role, "desk_access": desk}).insert(ignore_permissions=True)


def make_workspace():
	if frappe.db.exists("Workspace", WORKSPACE):
		return
	content = [
		{"id": "hdr", "type": "header", "data": {"text": "<span class=\"h4\"><b>SIO Connect</b></span>", "col": 12}},
	]
	content += [
		{"id": f"sc{i}", "type": "shortcut", "data": {"shortcut_name": label, "col": 3}}
		for i, (label, _link, _type) in enumerate(SHORTCUTS)
	]
	ws = frappe.get_doc(
		{
			"doctype": "Workspace",
			"name": WORKSPACE,
			"label": WORKSPACE,
			"title": WORKSPACE,
			"module": "SIO Connect",
			"public": 1,
			"icon": "users",
			"content": json.dumps(content),
			"shortcuts": [
				{"label": label, "link_to": link, "type": type_, "color": "Grey"}
				for label, link, type_ in SHORTCUTS
			],
			"roles": [{"role": r} for r in DESK_ROLES],
		}
	)
	ws.insert(ignore_permissions=True)
