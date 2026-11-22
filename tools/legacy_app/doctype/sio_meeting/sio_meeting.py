# Copyright (c) 2026, Hipersign and contributors
# For license information, please see license.txt

from frappe.model.document import Document


class SIOMeeting(Document):
	def validate(self):
		self.total_count = len(self.attendance)
		self.present_count = sum(1 for r in self.attendance if r.status == "Present")
