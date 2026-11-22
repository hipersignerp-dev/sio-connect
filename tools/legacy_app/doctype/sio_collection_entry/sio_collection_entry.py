# Copyright (c) 2026, Hipersign and contributors
# For license information, please see license.txt

from frappe.model.document import Document
from frappe.utils import flt


class SIOCollectionEntry(Document):
	def validate(self):
		if self.entry_type == "Items":
			self.payments = []
			self.paid_amount = 0
			self.offered_amount = 0
			self.balance_amount = 0
			self.status = "Items Received"
			return
		self.paid_amount = sum(flt(p.amount) for p in self.payments)
		if self.entry_type == "Payment":
			self.offered_amount = self.paid_amount
		self.balance_amount = max(flt(self.offered_amount) - self.paid_amount, 0)
		if self.paid_amount <= 0:
			self.status = "Offered"
		elif self.paid_amount < flt(self.offered_amount):
			self.status = "Part Paid"
		else:
			self.status = "Paid"
