# Units for the sign-up screen (guest).
frappe.response["message"] = frappe.get_all(
    "SIO Unit", filters={"active": 1}, fields=["name", "district"], order_by="district asc, name asc")
