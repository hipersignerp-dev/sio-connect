# The problems and ideas I sent, with their status and the team's reply (newest first).
rows = frappe.get_all("SIO Feedback", filters={"user": frappe.session.user, "kind": ["!=", "App error"]},
                      fields=["name", "kind", "status", "summary", "message", "reply", "replied_on", "creation"],
                      order_by="creation desc", limit=50)
frappe.response["message"] = rows
