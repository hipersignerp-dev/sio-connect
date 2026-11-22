# Copyright (c) 2026, Hipersign and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document
from frappe.utils import today


class SIOExpenseClaim(Document):
	def validate(self):
		before = self.get_doc_before_save()
		if before and before.status != self.status and self.status in ("Approved", "Rejected"):
			self.approved_by = frappe.session.user
		if self.status == "Paid" and not self.paid_on:
			self.paid_on = today()
