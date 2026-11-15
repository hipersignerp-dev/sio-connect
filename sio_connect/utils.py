"""Shared helpers: SIO roles, who the current user is, and what they may do."""

import frappe
from frappe import _

# ERP roles created on install
ROLE_ASSOCIATE = "SIO Associate"
ROLE_MEMBER = "SIO Member"
ROLE_UNIT_ADMIN = "SIO Unit Admin"
ROLE_FINANCE = "SIO Finance"
ROLE_ADMIN = "SIO Admin"
ALL_ROLES = (ROLE_ASSOCIATE, ROLE_MEMBER, ROLE_UNIT_ADMIN, ROLE_FINANCE, ROLE_ADMIN)
# roles that use the ERP desk; associates and members use only the phone app
DESK_ROLES = (ROLE_UNIT_ADMIN, ROLE_FINANCE, ROLE_ADMIN)

# member role (on SIO Member) -> ERP roles
ROLE_MAP = {
	"Associate": [ROLE_ASSOCIATE],
	"Member": [ROLE_MEMBER],
	"Unit Secretary": [ROLE_MEMBER, ROLE_UNIT_ADMIN],
	"Unit President": [ROLE_MEMBER, ROLE_UNIT_ADMIN],
	"Finance": [ROLE_MEMBER, ROLE_FINANCE],
	"District Admin": [ROLE_MEMBER, ROLE_UNIT_ADMIN, ROLE_FINANCE, ROLE_ADMIN],
}


def sync_user_roles(member):
	"""Give the member's User exactly the SIO roles their role and status call for."""
	if not member.user or not frappe.db.exists("User", member.user):
		return
	user = frappe.get_doc("User", member.user)
	if member.status == "Active":
		wanted = set(ROLE_MAP.get(member.member_role, [ROLE_ASSOCIATE]))
	elif member.status == "Pending Approval":
		wanted = {ROLE_ASSOCIATE}
	else:
		wanted = set()
	have = {r.role for r in user.roles if r.role in ALL_ROLES}
	if have == wanted and user.enabled == (1 if member.status != "Rejected" else 0):
		return
	user.roles = [r for r in user.roles if r.role not in ALL_ROLES]
	for role in sorted(wanted):
		user.append("roles", {"role": role})
	user.enabled = 0 if member.status == "Rejected" else 1
	user.flags.ignore_permissions = True
	user.save()


class Ctx:
	"""The signed-in user's member record and permissions."""

	def __init__(self, user=None):
		self.user = user or frappe.session.user
		if self.user in (None, "Guest"):
			frappe.throw(_("Please sign in."), frappe.AuthenticationError)
		roles = set(frappe.get_roles(self.user))
		self.is_sys = "System Manager" in roles or self.user == "Administrator"
		self.is_admin = self.is_sys or ROLE_ADMIN in roles
		self.is_finance = self.is_admin or ROLE_FINANCE in roles
		self.is_unit_admin = self.is_admin or ROLE_UNIT_ADMIN in roles
		name = frappe.db.get_value("SIO Member", {"user": self.user}, "name")
		self.member = frappe.get_doc("SIO Member", name) if name else None
		self.unit = self.member.unit if self.member else None
		self.status = self.member.status if self.member else ("Active" if self.is_admin else "None")
		self.active = self.status == "Active"
		self.is_member = self.active and (self.is_unit_admin or self.is_finance or ROLE_MEMBER in roles)

	# --- capabilities: the phone app shows or hides screens from these ---
	def capabilities(self):
		return {
			"rsvp": self.active,
			"register_events": self.status in ("Active", "Pending Approval"),
			"pledge": self.status in ("Active", "Pending Approval"),
			"collect": self.is_member,
			"claim_expense": self.is_member,
			"view_members": self.is_unit_admin,
			"approve_members": self.is_unit_admin,
			"mark_attendance": self.is_unit_admin,
			"schedule_meeting": self.is_unit_admin,
			"view_collection_totals": self.is_unit_admin or self.is_finance,
			"approve_expense": self.is_finance,
			"send_notice": self.is_unit_admin,
			"all_units": self.is_admin or self.is_finance,
		}

	def require(self, cap):
		if not self.capabilities().get(cap):
			frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)

	def need_member(self):
		if not self.member:
			frappe.throw(_("This account has no SIO member record. Ask the admin to link one."))
		return self.member

	def unit_scope(self):
		"""None = every unit; otherwise the one unit this person manages."""
		if self.is_admin or self.is_finance:
			return None
		return self.unit or "__none__"

	def check_unit(self, unit):
		scope = self.unit_scope()
		if scope is not None and unit != scope:
			frappe.throw(_("That belongs to another unit."), frappe.PermissionError)


def refresh_event_totals(doc, method=None):
	"""Registered count and approved spend on the event."""
	event = doc.get("event")
	if not event or not frappe.db.exists("SIO Event", event):
		return
	registered = frappe.db.count("SIO Event Registration", {"event": event, "status": ["!=", "Cancelled"]})
	spent = frappe.db.sql(
		"""select coalesce(sum(amount), 0) from `tabSIO Expense Claim`
		where event=%s and status in ('Approved', 'Paid')""",
		event,
	)[0][0]
	frappe.db.set_value("SIO Event", event, {"registered_count": registered, "spent": spent},
	                    update_modified=False)
