# Copyright (c) 2026, Hipersign and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document
from frappe.utils import now_datetime


class SIONotice(Document):
	def validate(self):
		if not self.sent_on:
			self.sent_on = now_datetime()
			self.sent_by = frappe.session.user
		self.recipient_count = len(audience_members(self))


def audience_members(notice):
	"""Names of the active or pending members a notice goes to."""
	filters = {"status": ["in", ["Active", "Pending Approval"]]}
	if notice.audience == "Unit":
		filters["unit"] = notice.unit
	elif notice.audience == "Role":
		filters["member_role"] = notice.member_role
	elif notice.audience == "Event Registrants":
		members = frappe.get_all(
			"SIO Event Registration", filters={"event": notice.event, "status": ["!=", "Cancelled"]}, pluck="member"
		)
		filters["name"] = ["in", members or ["__none__"]]
	return frappe.get_all("SIO Member", filters=filters, pluck="name")
