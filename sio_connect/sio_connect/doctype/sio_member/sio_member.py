# Copyright (c) 2026, Hipersign and contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document
from frappe.utils import now_datetime, today

from sio_connect.utils import sync_user_roles


class SIOMember(Document):
	def validate(self):
		self.mobile = (self.mobile or "").replace(" ", "")
		dup = frappe.db.get_value("SIO Member", {"mobile": self.mobile, "name": ["!=", self.name]})
		if dup:
			frappe.throw(_("Mobile {0} is already registered ({1}).").format(self.mobile, dup))
		if self.status == "Active" and not self.joined_on:
			self.joined_on = today()
		before = self.get_doc_before_save()
		if before and before.status == "Pending Approval" and self.status == "Active":
			self.approved_by = frappe.session.user
			self.approved_on = now_datetime()

	def on_update(self):
		sync_user_roles(self)
