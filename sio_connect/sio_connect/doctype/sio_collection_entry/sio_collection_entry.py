# Copyright (c) 2026, Hipersign and contributors
# For license information, please see license.txt

from frappe.model.document import Document
from frappe.utils import flt


class SIOCollectionEntry(Document):
	def validate(self):
		if self.entry_type == "In-kind":
			self.payments = []
			self.paid_amount = 0
			self.pledged_amount = 0
			self.balance_amount = 0
			self.status = "In-kind Received"
			return
		self.paid_amount = sum(flt(p.amount) for p in self.payments)
		if self.entry_type == "Payment":
			self.pledged_amount = self.paid_amount
		self.balance_amount = max(flt(self.pledged_amount) - self.paid_amount, 0)
		if self.paid_amount <= 0:
			self.status = "Pledged"
		elif self.paid_amount < flt(self.pledged_amount):
			self.status = "Part Paid"
		else:
			self.status = "Paid"
