"""Generate Frappe DocType JSON + controller stubs for sio_connect from compact specs.

Usage: python3 gen_doctypes.py <repo_root>
Field spec: (fieldname, fieldtype, label, {extra props})
"""
import json
import os
import sys

ROOT = sys.argv[1]
MODULE = "SIO Connect"
APP = "sio_connect"
TS = "2026-11-15 12:00:00.000000"

ADMIN = ["System Manager", "SIO Admin"]


def perm(role, write=True, create=True, delete=False, submit=False):
	p = {"role": role, "read": 1, "report": 1, "export": 1, "print": 1, "email": 1, "share": 1}
	if write:
		p["write"] = 1
	if create:
		p["create"] = 1
	if delete:
		p["delete"] = 1
	return p


def admin_perms(extra=None):
	ps = [perm(r, delete=True) for r in ADMIN]
	for role, kw in (extra or []):
		ps.append(perm(role, **kw))
	return ps


def F(name, ftype, label=None, **kw):
	d = {"fieldname": name, "fieldtype": ftype}
	if label:
		d["label"] = label
	if "options" in kw and isinstance(kw["options"], (list, tuple)):
		kw["options"] = "\n".join(kw["options"])
	d.update(kw)
	return d


def colbreak(n):
	return F(n, "Column Break")


def section(n, label=None, **kw):
	return F(n, "Section Break", label, **kw)


ROLES = ["Associate", "Member", "Unit Secretary", "Unit President", "Finance", "District Admin"]

DOCTYPES = [
	dict(
		name="SIO Unit",
		autoname="field:unit_name",
		title_field="unit_name",
		search_fields="district",
		fields=[
			F("unit_name", "Data", "Unit Name", reqd=1, unique=1, in_list_view=1),
			F("district", "Data", "District", in_list_view=1, in_standard_filter=1),
			F("area", "Data", "Area / Campus Zone"),
			colbreak("col_a"),
			F("president", "Link", "President", options="SIO Member"),
			F("secretary", "Link", "Secretary", options="SIO Member"),
			F("active", "Check", "Active", default="1", in_list_view=1),
		],
		permissions=admin_perms([("SIO Unit Admin", dict(write=False, create=False))]),
		sort_field="unit_name",
	),
	dict(
		name="SIO Member",
		autoname="naming_series:",
		title_field="full_name",
		search_fields="full_name,mobile,unit",
		show_title_field_in_link=1,
		fields=[
			F("naming_series", "Select", "Series", options=["SIO-MEM-.#####"], default="SIO-MEM-.#####", hidden=1),
			F("full_name", "Data", "Full Name", reqd=1, in_list_view=1, in_global_search=1),
			F("mobile", "Data", "Mobile", options="Phone", reqd=1, in_list_view=1),
			F("email", "Data", "Email", options="Email"),
			F("user", "Link", "User", options="User", unique=1,
			  description="The ERP login of this member. Set automatically when they register in the app."),
			colbreak("col_a"),
			F("member_role", "Select", "Role", options=ROLES, default="Associate", reqd=1, in_list_view=1,
			  in_standard_filter=1),
			F("status", "Select", "Status", options=["Pending Approval", "Active", "Inactive", "Rejected"],
			  default="Pending Approval", reqd=1, in_list_view=1, in_standard_filter=1),
			F("unit", "Link", "Unit", options="SIO Unit", in_list_view=1, in_standard_filter=1),
			F("joined_on", "Date", "Joined On"),
			section("study_section", "Study"),
			F("campus", "Data", "Campus / College"),
			F("course", "Data", "Course"),
			colbreak("col_b"),
			F("year_of_study", "Select", "Year", options=["", "1st Year", "2nd Year", "3rd Year", "4th Year",
			                                                "5th Year", "PG 1st Year", "PG 2nd Year", "Research", "Other"]),
			F("home_town", "Data", "Home Town"),
			section("approval_section", "Approval", collapsible=1),
			F("approved_by", "Link", "Approved By", options="User", read_only=1),
			F("approved_on", "Datetime", "Approved On", read_only=1),
		],
		permissions=admin_perms([("SIO Unit Admin", dict(create=False))]),
		sort_field="creation",
	),
	dict(
		name="SIO Meeting Attendance",
		istable=1,
		fields=[
			F("member", "Link", "Member", options="SIO Member", reqd=1, in_list_view=1),
			F("member_name", "Data", "Name", fetch_from="member.full_name", read_only=1, in_list_view=1),
			F("status", "Select", "Attendance", options=["Absent", "Present", "Excused"], default="Absent",
			  in_list_view=1),
			F("rsvp", "Select", "RSVP", options=["", "Attending", "Not Attending"], in_list_view=1),
		],
	),
	dict(
		name="SIO Meeting",
		autoname="naming_series:",
		title_field="topic",
		fields=[
			F("naming_series", "Select", "Series", options=["MTG-.YYYY.-.#####"], default="MTG-.YYYY.-.#####",
			  hidden=1),
			F("unit", "Link", "Unit", options="SIO Unit", reqd=1, in_list_view=1, in_standard_filter=1),
			F("meeting_type", "Select", "Type", options=["Weekly Meeting", "Study Circle", "Executive Meeting",
			                                            "Special Meeting"], default="Weekly Meeting"),
			F("topic", "Data", "Topic", reqd=1, in_list_view=1),
			colbreak("col_a"),
			F("meeting_date", "Date", "Date", reqd=1, in_list_view=1),
			F("meeting_time", "Time", "Time"),
			F("venue", "Data", "Venue"),
			F("status", "Select", "Status", options=["Scheduled", "Completed", "Cancelled"], default="Scheduled",
			  in_list_view=1, in_standard_filter=1),
			section("agenda_section", "Agenda & Minutes"),
			F("agenda", "Small Text", "Agenda"),
			F("minutes", "Text Editor", "Minutes"),
			section("attendance_section", "Attendance"),
			F("present_count", "Int", "Present", read_only=1),
			colbreak("col_b"),
			F("total_count", "Int", "Total", read_only=1),
			section("attendance_table_section"),
			F("attendance", "Table", "Attendance", options="SIO Meeting Attendance"),
		],
		permissions=admin_perms([("SIO Unit Admin", dict(delete=False))]),
		sort_field="meeting_date",
	),
	dict(
		name="SIO Event",
		autoname="naming_series:",
		title_field="title",
		fields=[
			F("naming_series", "Select", "Series", options=["EVT-.#####"], default="EVT-.#####", hidden=1),
			F("title", "Data", "Title", reqd=1, in_list_view=1),
			F("event_type", "Select", "Type", options=["Campus Programme", "Camp", "Workshop", "Conference",
			                                          "Iftar", "Other"], default="Campus Programme"),
			F("starts_on", "Datetime", "Starts On", reqd=1, in_list_view=1),
			F("ends_on", "Datetime", "Ends On"),
			F("venue", "Data", "Venue"),
			colbreak("col_a"),
			F("status", "Select", "Status", options=["Planning", "Registrations Open", "Registrations Closed",
			                                        "Completed", "Cancelled"], default="Planning",
			  in_list_view=1, in_standard_filter=1),
			F("open_to", "Select", "Open To", options=["Everyone", "Members Only"], default="Everyone"),
			F("unit", "Link", "Unit (blank = all units)", options="SIO Unit"),
			F("capacity", "Int", "Capacity"),
			section("money_section", "Budget"),
			F("budget", "Currency", "Budget"),
			colbreak("col_b"),
			F("spent", "Currency", "Spent (approved expenses)", read_only=1),
			F("registered_count", "Int", "Registered", read_only=1),
			section("desc_section", "Details"),
			F("description", "Text Editor", "Description"),
		],
		permissions=admin_perms([("SIO Unit Admin", dict())]),
		sort_field="starts_on",
	),
	dict(
		name="SIO Event Registration",
		autoname="naming_series:",
		fields=[
			F("naming_series", "Select", "Series", options=["EVR-.#####"], default="EVR-.#####", hidden=1),
			F("event", "Link", "Event", options="SIO Event", reqd=1, in_list_view=1, in_standard_filter=1),
			F("member", "Link", "Member", options="SIO Member", reqd=1, in_list_view=1),
			F("member_name", "Data", "Name", fetch_from="member.full_name", read_only=1, in_list_view=1),
			F("status", "Select", "Status", options=["Registered", "Cancelled", "Attended"], default="Registered",
			  in_list_view=1),
		],
		permissions=admin_perms([("SIO Unit Admin", dict())]),
	),
	dict(
		name="SIO Collection Unit Target",
		istable=1,
		fields=[
			F("unit", "Link", "Unit", options="SIO Unit", reqd=1, in_list_view=1),
			F("target", "Currency", "Target", reqd=1, in_list_view=1),
		],
	),
	dict(
		name="SIO Collection",
		autoname="field:collection_name",
		title_field="collection_name",
		search_fields="collection_type",
		fields=[
			F("collection_name", "Data", "Collection", reqd=1, unique=1, in_list_view=1,
			  description="e.g. Ramadan Collection 1448, Baithul Mal 2026-27"),
			F("collection_type", "Select", "Type",
			  options=["Ramadan Collection", "Baithul Mal", "Zakat", "Relief Fund", "Other"],
			  default="Ramadan Collection", reqd=1, in_list_view=1, in_standard_filter=1),
			F("is_active", "Check", "Open", default="1", in_list_view=1,
			  description="Open collections show in the app"),
			colbreak("col_a"),
			F("unit", "Link", "Unit (blank = all units)", options="SIO Unit", in_standard_filter=1),
			F("target_amount", "Currency", "Target (optional)"),
			F("starts_on", "Date", "Starts On"),
			F("ends_on", "Date", "Ends On"),
			section("desc_section"),
			F("description", "Small Text", "Description", description="Shown to members in the app"),
			section("targets_section", "Unit targets",
			        description="Split the area target among units. Each unit's progress is tracked against its target."),
			F("unit_targets", "Table", "Unit Targets", options="SIO Collection Unit Target"),
			F("unit_targets_total", "Currency", "Total of unit targets", read_only=1),
		],
		permissions=admin_perms([("SIO Finance", dict(delete=False)), ("SIO Unit Admin", dict(write=False, create=False))]),
	),
	dict(
		name="SIO Collection Payment",
		istable=1,
		fields=[
			F("payment_date", "Date", "Date", reqd=1, in_list_view=1, default="Today"),
			F("amount", "Currency", "Amount", reqd=1, in_list_view=1),
			F("mode", "Select", "Mode", options=["Cash", "UPI", "Bank Transfer", "Cheque"], default="Cash",
			  in_list_view=1),
			F("reference_no", "Data", "Reference", in_list_view=1),
			F("received_by", "Link", "Received By", options="SIO Member"),
		],
	),
	dict(
		name="SIO Collection Entry",
		autoname="naming_series:",
		title_field="contributor_name",
		search_fields="contributor_name,contributor_mobile",
		fields=[
			F("naming_series", "Select", "Series", options=["COL-.YYYY.-.#####"], default="COL-.YYYY.-.#####",
			  hidden=1),
			F("collection", "Link", "Collection", options="SIO Collection", reqd=1, in_list_view=1,
			  in_standard_filter=1),
			F("entry_type", "Select", "Type", options=["Offer", "Payment", "Items"], default="Offer",
			  reqd=1, in_list_view=1, in_standard_filter=1,
			  description="Offer: will pay later. Payment: paid now. Items: food kits, clothes, etc."),
			F("contributor_name", "Data", "Given By", reqd=1, in_list_view=1),
			F("contributor_type", "Select", "Giver Type",
			  options=["Member", "Associate", "Alumni", "Well-wisher", "Business", "Unit"], default="Well-wisher"),
			F("contributor_member", "Link", "Member (if a member)", options="SIO Member"),
			F("contributor_mobile", "Data", "Mobile", options="Phone"),
			F("contributor_place", "Data", "Place / Address"),
			colbreak("col_a"),
			F("unit", "Link", "Unit", options="SIO Unit", in_standard_filter=1),
			F("collected_by", "Link", "Collected By", options="SIO Member"),
			F("status", "Select", "Status", options=["Offered", "Part Paid", "Paid", "Items Received"],
			  read_only=1, in_list_view=1, in_standard_filter=1),
			section("amount_section", "Amounts"),
			F("offered_amount", "Currency", "Amount Offered", depends_on="eval:doc.entry_type=='Offer'"),
			F("items_given", "Small Text", "Items Given", depends_on="eval:doc.entry_type=='Items'"),
			F("items_value", "Currency", "Value of Items (approx.)", depends_on="eval:doc.entry_type=='Items'"),
			colbreak("col_b"),
			F("paid_amount", "Currency", "Received", read_only=1, in_list_view=1),
			F("balance_amount", "Currency", "Still to Receive", read_only=1),
			section("payments_section", "Payments received",
			        depends_on="eval:doc.entry_type!='Items'"),
			F("payments", "Table", "Payments", options="SIO Collection Payment"),
		],
		permissions=admin_perms([("SIO Finance", dict(delete=False)), ("SIO Unit Admin", dict(delete=False))]),
	),
	dict(
		name="SIO Expense Claim",
		autoname="naming_series:",
		title_field="description",
		fields=[
			F("naming_series", "Select", "Series", options=["SEC-.YYYY.-.#####"], default="SEC-.YYYY.-.#####",
			  hidden=1),
			F("description", "Data", "Description", reqd=1, in_list_view=1),
			F("category", "Select", "Category",
			  options=["Venue", "Food", "Printing", "Travel", "Rent", "Materials", "Other"], default="Other",
			  in_standard_filter=1),
			F("amount", "Currency", "Amount", reqd=1, in_list_view=1),
			F("expense_date", "Date", "Expense Date", default="Today"),
			F("bill", "Attach", "Bill / Receipt"),
			colbreak("col_a"),
			F("status", "Select", "Status", options=["Pending", "Approved", "Rejected", "Paid"], default="Pending",
			  in_list_view=1, in_standard_filter=1),
			F("claimed_by", "Link", "Claimed By", options="SIO Member", reqd=1),
			F("claimed_by_name", "Data", "Claimed By Name", fetch_from="claimed_by.full_name", read_only=1,
			  in_list_view=1),
			F("unit", "Link", "Unit", options="SIO Unit", in_standard_filter=1),
			F("event", "Link", "Event", options="SIO Event", in_standard_filter=1),
			F("paid_from", "Link", "Paid From (fund)", options="SIO Collection", in_standard_filter=1,
			  description="Which collection's money paid this, e.g. Baithul Mal for relief. Shows in that fund's accounts."),
			section("approval_section", "Approval"),
			F("approved_by", "Link", "Approved By", options="User", read_only=1),
			F("paid_on", "Date", "Paid On"),
			colbreak("col_b"),
			F("payment_mode", "Select", "Payment Mode", options=["", "Cash", "UPI", "Bank Transfer"]),
			F("remarks", "Small Text", "Remarks"),
		],
		permissions=admin_perms([("SIO Finance", dict(delete=False)), ("SIO Unit Admin", dict(delete=False))]),
	),
	dict(
		name="SIO Notice",
		autoname="naming_series:",
		title_field="title",
		fields=[
			F("naming_series", "Select", "Series", options=["NTC-.YYYY.-.#####"], default="NTC-.YYYY.-.#####",
			  hidden=1),
			F("title", "Data", "Title", reqd=1, in_list_view=1),
			F("message", "Small Text", "Message", reqd=1),
			colbreak("col_a"),
			F("audience", "Select", "Send To", options=["Everyone", "Unit", "Role", "Event Registrants"],
			  default="Everyone", reqd=1, in_list_view=1),
			F("unit", "Link", "Unit", options="SIO Unit", depends_on="eval:doc.audience=='Unit'"),
			F("member_role", "Select", "Role", options=[""] + ROLES, depends_on="eval:doc.audience=='Role'"),
			F("event", "Link", "Event", options="SIO Event", depends_on="eval:doc.audience=='Event Registrants'"),
			section("delivery_section", "Delivery"),
			F("send_whatsapp", "Check", "Also send on WhatsApp"),
			F("send_email", "Check", "Also send by email"),
			colbreak("col_b"),
			F("sent_by", "Link", "Sent By", options="User", read_only=1),
			F("sent_on", "Datetime", "Sent On", read_only=1, in_list_view=1),
			F("recipient_count", "Int", "Recipients", read_only=1),
		],
		permissions=admin_perms([("SIO Unit Admin", dict(delete=False))]),
		sort_field="creation",
	),
	dict(
		name="SIO Device Token",
		autoname="hash",
		fields=[
			F("user", "Link", "User", options="User", reqd=1, read_only=1, in_list_view=1),
			F("device_name", "Data", "Device", read_only=1, in_list_view=1),
			F("token_hash", "Data", "Token Hash", read_only=1, hidden=1),
			colbreak("col_a"),
			F("last_used", "Datetime", "Last Used", read_only=1, in_list_view=1),
			F("revoked", "Check", "Revoked", in_list_view=1,
			  description="Tick to stop fingerprint login on this phone"),
		],
		permissions=[perm(r, create=False, delete=True) for r in ADMIN],
		description="Phones allowed to sign in with fingerprint. Created by the app. Tick Revoked to block a phone.",
	),
]


def snake(name):
	return name.lower().replace(" ", "_").replace("-", "_")


def classname(name):
	return name.replace(" ", "").replace("-", "")


def build(spec):
	name = spec["name"]
	fields = spec["fields"]
	doc = {
		"actions": [],
		"allow_rename": 0,
		"creation": TS,
		"doctype": "DocType",
		"engine": "InnoDB",
		"field_order": [f["fieldname"] for f in fields],
		"fields": fields,
		"index_web_pages_for_search": 0,
		"links": [],
		"modified": TS,
		"modified_by": "Administrator",
		"module": MODULE,
		"name": name,
		"owner": "Administrator",
		"permissions": spec.get("permissions", []),
		"sort_field": spec.get("sort_field", "creation"),
		"sort_order": "DESC",
		"states": [],
		"track_changes": 0 if spec.get("istable") else 1,
	}
	for key in ("autoname", "title_field", "search_fields", "show_title_field_in_link", "description"):
		if key in spec:
			doc[key] = spec[key]
	if spec.get("istable"):
		doc["istable"] = 1
		doc["editable_grid"] = 1
		doc["permissions"] = []
	if "autoname" in spec and spec["autoname"].startswith("naming_series"):
		doc["naming_rule"] = "By \"Naming Series\" field"
	elif "autoname" in spec and spec["autoname"].startswith("field:"):
		doc["naming_rule"] = "By fieldname"
	elif spec.get("autoname") == "hash":
		doc["naming_rule"] = "Random"
	return doc


base = os.path.join(ROOT, APP, APP, "doctype")
os.makedirs(base, exist_ok=True)
open(os.path.join(base, "__init__.py"), "a").close()
for spec in DOCTYPES:
	folder = os.path.join(base, snake(spec["name"]))
	os.makedirs(folder, exist_ok=True)
	open(os.path.join(folder, "__init__.py"), "a").close()
	with open(os.path.join(folder, snake(spec["name"]) + ".json"), "w") as fh:
		json.dump(build(spec), fh, indent=1, ensure_ascii=False)
		fh.write("\n")
	py = os.path.join(folder, snake(spec["name"]) + ".py")
	if not os.path.exists(py):
		with open(py, "w") as fh:
			fh.write(
				"# Copyright (c) 2026, Hipersign and contributors\n# For license information, please see license.txt\n\n"
				"from frappe.model.document import Document\n\n\n"
				f"class {classname(spec['name'])}(Document):\n\tpass\n"
			)
print("generated", len(DOCTYPES), "doctypes")
