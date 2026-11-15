# Copyright (c) 2026, Hipersign and contributors
# For license information, please see license.txt

from frappe.model.document import Document


class SIODeviceToken(Document):
	def on_update(self):
		# ticking Revoked stops fingerprint sign-in on that phone
		if self.revoked and self.has_value_changed("revoked"):
			from sio_connect.api.auth import replace_secret

			replace_secret(self.user)
