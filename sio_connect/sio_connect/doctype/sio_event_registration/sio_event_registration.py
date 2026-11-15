# Copyright (c) 2026, Hipersign and contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document


class SIOEventRegistration(Document):
	def validate(self):
		dup = frappe.db.get_value(
			"SIO Event Registration",
			{"event": self.event, "member": self.member, "name": ["!=", self.name], "status": ["!=", "Cancelled"]},
		)
		if dup and self.status != "Cancelled":
			frappe.throw(_("Already registered for this event."))
