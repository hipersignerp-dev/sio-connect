"""Data for the SIO phone app. Every call works out who the person is and returns only what their role
allows (see sio_connect.utils.Ctx.capabilities). Writes go through these checks, then save with
ignore_permissions, so associates and members never need desk access."""

import base64
import json

import frappe
from frappe import _
from frappe.utils import add_days, cint, flt, getdate, now_datetime, nowdate

from sio_connect.sio_connect.doctype.sio_notice.sio_notice import audience_members
from sio_connect.utils import Ctx

MEMBER_ROLES_UNIT_ADMIN_CAN_GIVE = ("Associate", "Member")


def _loads(value, default=None):
	if value in (None, ""):
		return default
	if isinstance(value, (list, dict)):
		return value
	return json.loads(value)


# --------------------------------------------------------------------------------------- profile


@frappe.whitelist()
def me():
	ctx = Ctx()
	m = ctx.member
	return {
		"user": ctx.user,
		"full_name": m.full_name if m else frappe.utils.get_fullname(ctx.user),
		"member": m.name if m else None,
		"member_role": m.member_role if m else ("District Admin" if ctx.is_admin else None),
		"status": ctx.status,
		"unit": ctx.unit,
		"mobile": m.mobile if m else None,
		"email": m.email if m else ctx.user,
		"campus": m.campus if m else None,
		"course": m.course if m else None,
		"year_of_study": m.year_of_study if m else None,
		"home_town": m.home_town if m else None,
		"joined_on": m.joined_on if m else None,
		"capabilities": ctx.capabilities(),
	}


@frappe.whitelist(methods=["POST"])
def update_my_profile(campus=None, course=None, year_of_study=None, home_town=None, unit=None):
	ctx = Ctx()
	if not ctx.member:
		frappe.throw(_("No member record for this account."))
	m = ctx.member
	for field, value in (("campus", campus), ("course", course), ("home_town", home_town),
	                     ("year_of_study", year_of_study)):
		if value is not None:
			m.set(field, value)
	if unit and m.status == "Pending Approval":  # unit is fixed once approved
		m.unit = unit
	m.save(ignore_permissions=True)
	return me()


# ------------------------------------------------------------------------------------------- home


@frappe.whitelist()
def home():
	ctx = Ctx()
	caps = ctx.capabilities()
	out = {"me": me(), "next_meeting": None, "next_event": None, "notices": _notices_for(ctx, limit=3)}

	if ctx.unit:
		rows = frappe.get_all(
			"SIO Meeting",
			filters={"unit": ctx.unit, "status": "Scheduled", "meeting_date": [">=", nowdate()]},
			fields=["name", "topic", "meeting_type", "meeting_date", "meeting_time", "venue", "unit"],
			order_by="meeting_date asc, meeting_time asc",
			limit=1,
		)
		if rows:
			mt = rows[0]
			mt["my_rsvp"] = _my_row(mt.name, ctx, "rsvp")
			out["next_meeting"] = mt
		if ctx.member:
			att = frappe.db.sql(
				"""select count(*), sum(a.status='Present') from `tabSIO Meeting Attendance` a
				join `tabSIO Meeting` m on m.name=a.parent
				where a.member=%s and m.status='Completed' and m.meeting_date >= %s""",
				(ctx.member.name, add_days(nowdate(), -180)),
			)[0]
			out["my_attendance"] = {"total": cint(att[0]), "present": cint(att[1])}

	events = _events_query(ctx, upcoming_only=True, limit=1)
	out["next_event"] = events[0] if events else None

	camp = _active_campaign()
	if camp:
		out["campaign"] = {"name": camp.name, "target": flt(camp.target_amount)}
		if caps["view_collection_totals"]:
			out["campaign"].update(_collection_totals(camp.name, ctx.unit_scope()))
		if ctx.member:
			out["my_pledges"] = _entries(
				{"campaign": camp.name, "contributor_member": ctx.member.name}, limit=20)
	if caps["view_members"]:
		scope = ctx.unit_scope()
		base = {"unit": scope} if scope else {}
		out["members"] = {
			"active": frappe.db.count("SIO Member", {**base, "status": "Active"}),
			"pending": frappe.db.count("SIO Member", {**base, "status": "Pending Approval"}),
		}
	if caps["approve_expense"]:
		pend = frappe.db.sql(
			"select count(*), coalesce(sum(amount),0) from `tabSIO Expense Claim` where status='Pending'")[0]
		out["pending_expenses"] = {"count": cint(pend[0]), "amount": flt(pend[1])}
	return out


# --------------------------------------------------------------------------------------- meetings


def _my_row(meeting, ctx, field):
	if not ctx.member:
		return None
	return frappe.db.get_value(
		"SIO Meeting Attendance", {"parent": meeting, "parenttype": "SIO Meeting", "member": ctx.member.name}, field
	)


def _meeting_access(ctx, unit):
	if ctx.is_admin or ctx.is_finance:
		return
	if unit != ctx.unit:
		frappe.throw(_("This meeting is for another unit."), frappe.PermissionError)


@frappe.whitelist()
def meetings(days_back=30):
	ctx = Ctx()
	filters = {"meeting_date": [">=", add_days(nowdate(), -cint(days_back))], "status": ["!=", "Cancelled"]}
	scope = ctx.unit_scope() if ctx.is_unit_admin else (ctx.unit or "__none__")
	if scope:
		filters["unit"] = scope
	rows = frappe.get_all(
		"SIO Meeting",
		filters=filters,
		fields=["name", "unit", "topic", "meeting_type", "meeting_date", "meeting_time", "venue", "status",
		        "present_count", "total_count"],
		order_by="meeting_date desc, meeting_time desc",
		limit=100,
	)
	for r in rows:
		r["my_status"] = _my_row(r.name, ctx, "status")
		r["my_rsvp"] = _my_row(r.name, ctx, "rsvp")
	this_week = [r for r in rows if getdate(r.meeting_date) >= getdate(add_days(nowdate(), -7))]
	done = [r for r in rows if r.status == "Completed" and r.total_count]
	return {
		"meetings": rows,
		"summary": {
			"this_week": len(this_week),
			"attendance_pct": round(100 * sum(r.present_count for r in done) / max(sum(r.total_count for r in done), 1)),
			"to_mark": sum(1 for r in rows if r.status == "Scheduled" and getdate(r.meeting_date) <= getdate()),
		},
	}


def _roster(unit):
	return frappe.get_all(
		"SIO Member", filters={"unit": unit, "status": "Active"}, fields=["name", "full_name", "member_role"],
		order_by="full_name asc",
	)


@frappe.whitelist()
def meeting(name):
	ctx = Ctx()
	doc = frappe.get_doc("SIO Meeting", name)
	_meeting_access(ctx, doc.unit)
	out = doc.as_dict(no_default_fields=True)
	out["my_rsvp"] = _my_row(name, ctx, "rsvp")
	if ctx.capabilities()["mark_attendance"]:
		rows = {r.member: r for r in doc.attendance}
		out["roster"] = [
			{
				"member": m.name,
				"full_name": m.full_name,
				"status": rows[m.name].status if m.name in rows else "Absent",
				"rsvp": rows[m.name].rsvp if m.name in rows else "",
			}
			for m in _roster(doc.unit)
		]
	else:
		out.pop("attendance", None)
	return out


@frappe.whitelist(methods=["POST"])
def rsvp(name, attending):
	ctx = Ctx()
	ctx.require("rsvp")
	ctx.need_member()
	doc = frappe.get_doc("SIO Meeting", name)
	if doc.unit != ctx.unit:
		frappe.throw(_("This meeting is for another unit."), frappe.PermissionError)
	value = "Attending" if cint(attending) else "Not Attending"
	row = next((r for r in doc.attendance if r.member == ctx.member.name), None)
	if row:
		row.rsvp = value
	else:
		doc.append("attendance", {"member": ctx.member.name, "status": "Absent", "rsvp": value})
	doc.save(ignore_permissions=True)
	return {"rsvp": value}


@frappe.whitelist(methods=["POST"])
def save_attendance(name, present, minutes=None, complete=1):
	"""present: JSON list of member names who came."""
	ctx = Ctx()
	ctx.require("mark_attendance")
	doc = frappe.get_doc("SIO Meeting", name)
	ctx.check_unit(doc.unit)
	present = set(_loads(present, []))
	existing = {r.member: r for r in doc.attendance}
	roster = [m.name for m in _roster(doc.unit)]
	members = roster + [m for m in existing if m not in set(roster)]
	doc.attendance = []
	for m in members:
		old = existing.get(m)
		status = "Present" if m in present else ("Excused" if old and old.status == "Excused" else "Absent")
		doc.append("attendance", {"member": m, "status": status, "rsvp": old.rsvp if old else ""})
	if minutes is not None:
		doc.minutes = minutes
	if cint(complete):
		doc.status = "Completed"
	doc.save(ignore_permissions=True)
	return {"present": doc.present_count, "total": doc.total_count}


@frappe.whitelist(methods=["POST"])
def schedule_meeting(topic, meeting_date, meeting_time=None, venue=None, meeting_type="Weekly Meeting",
                     agenda=None, unit=None):
	ctx = Ctx()
	ctx.require("schedule_meeting")
	unit = unit or ctx.unit
	if not unit:
		frappe.throw(_("Pick a unit."))
	ctx.check_unit(unit)
	doc = frappe.get_doc(
		{
			"doctype": "SIO Meeting",
			"unit": unit,
			"topic": topic,
			"meeting_type": meeting_type,
			"meeting_date": meeting_date,
			"meeting_time": meeting_time,
			"venue": venue,
			"agenda": agenda,
		}
	).insert(ignore_permissions=True)
	return {"name": doc.name}


# ----------------------------------------------------------------------------------------- events


def _events_query(ctx, upcoming_only=False, limit=50):
	conds = ["e.status != 'Cancelled'"]
	args = {}
	if upcoming_only:
		conds.append("e.starts_on >= %(now)s and e.status in ('Registrations Open', 'Planning')")
	else:
		conds.append("(e.starts_on >= %(since)s or e.status != 'Completed')")
	args["now"] = now_datetime()
	args["since"] = add_days(nowdate(), -60)
	if not ctx.capabilities()["all_units"]:
		conds.append("(ifnull(e.unit, '') = '' or e.unit = %(unit)s)")
		args["unit"] = ctx.unit or "__none__"
	if not ctx.is_member:
		conds.append("e.open_to = 'Everyone'")
	args["member"] = ctx.member.name if ctx.member else "__none__"
	rows = frappe.db.sql(
		f"""select e.name, e.title, e.event_type, e.starts_on, e.ends_on, e.venue, e.status, e.capacity,
			e.registered_count, e.budget, e.spent, e.unit, e.open_to,
			(select r.status from `tabSIO Event Registration` r where r.event=e.name and r.member=%(member)s
			 and r.status != 'Cancelled' limit 1) as my_registration
		from `tabSIO Event` e where {' and '.join(conds)}
		order by (e.status = 'Completed'), e.starts_on asc limit {cint(limit)}""",
		args,
		as_dict=True,
	)
	if not ctx.is_unit_admin:
		for r in rows:
			r.pop("budget", None)
			r.pop("spent", None)
	return rows


@frappe.whitelist()
def events():
	return _events_query(Ctx())


@frappe.whitelist()
def event(name):
	ctx = Ctx()
	rows = [e for e in _events_query(ctx, limit=500) if e.name == name]
	if not rows:
		frappe.throw(_("Event not found."), frappe.DoesNotExistError)
	out = rows[0]
	out["description"] = frappe.db.get_value("SIO Event", name, "description")
	return out


@frappe.whitelist(methods=["POST"])
def register_event(event, cancel=0):
	ctx = Ctx()
	ctx.require("register_events")
	ctx.need_member()
	ev = frappe.get_doc("SIO Event", event)
	if ev.open_to == "Members Only" and not ctx.is_member:
		frappe.throw(_("This event is for members only."))
	existing = frappe.db.get_value(
		"SIO Event Registration", {"event": event, "member": ctx.member.name, "status": ["!=", "Cancelled"]})
	if cint(cancel):
		if existing:
			frappe.db.set_value("SIO Event Registration", existing, "status", "Cancelled")
			frappe.get_doc("SIO Event Registration", existing).run_method("on_update")
		return {"registered": False}
	if existing:
		return {"registered": True}
	if ev.status != "Registrations Open":
		frappe.throw(_("Registrations are not open for this event."))
	if ev.capacity and ev.registered_count >= ev.capacity:
		frappe.throw(_("Sorry, this event is full."))
	frappe.get_doc({"doctype": "SIO Event Registration", "event": event, "member": ctx.member.name}).insert(
		ignore_permissions=True)
	return {"registered": True}


# ------------------------------------------------------------------------------------- collection


def _active_campaign(name=None):
	if name:
		return frappe.get_doc("SIO Collection Campaign", name)
	n = frappe.db.get_value("SIO Collection Campaign", {"is_active": 1}, "name", order_by="creation desc")
	return frappe.get_doc("SIO Collection Campaign", n) if n else None


def _collection_totals(campaign, unit=None):
	cond, args = "campaign=%s", [campaign]
	if unit:
		cond += " and unit=%s"
		args.append(unit)
	r = frappe.db.sql(
		f"""select
			coalesce(sum(case when entry_type!='In-kind' then pledged_amount end), 0),
			coalesce(sum(case when entry_type!='In-kind' then paid_amount end), 0),
			coalesce(sum(case when entry_type!='In-kind' then balance_amount end), 0),
			coalesce(sum(case when entry_type='In-kind' then in_kind_value end), 0),
			count(*)
		from `tabSIO Collection Entry` where {cond}""",
		args,
	)[0]
	return {"pledged": flt(r[0]), "collected": flt(r[1]), "balance": flt(r[2]), "in_kind": flt(r[3]),
	        "entries": cint(r[4])}


def _entries(filters, limit=200):
	return frappe.get_all(
		"SIO Collection Entry",
		filters=filters,
		fields=["name", "entry_type", "contributor_name", "contributor_type", "contributor_mobile", "unit",
		        "pledged_amount", "paid_amount", "balance_amount", "in_kind_value", "in_kind_details", "status",
		        "collected_by", "creation"],
		order_by="creation desc",
		limit=limit,
	)


@frappe.whitelist()
def collection(campaign=None, status=None):
	ctx = Ctx()
	caps = ctx.capabilities()
	camp = _active_campaign(campaign)
	if not camp:
		return {"campaign": None}
	out = {
		"campaign": {"name": camp.name, "target": flt(camp.target_amount), "starts_on": camp.starts_on,
		             "ends_on": camp.ends_on, "description": camp.description},
		"my_pledges": _entries({"campaign": camp.name, "contributor_member": ctx.member.name})
		if ctx.member else [],
	}
	filters = {"campaign": camp.name}
	if status:
		filters["status"] = status
	if caps["view_collection_totals"]:
		scope = ctx.unit_scope()
		if scope:
			filters["unit"] = scope
		out["totals"] = _collection_totals(camp.name, scope)
		out["entries"] = _entries(filters)
	elif caps["collect"]:
		filters["collected_by"] = ctx.member.name
		out["entries"] = _entries(filters)
		mine = _entries({"campaign": camp.name, "collected_by": ctx.member.name}, limit=1000)
		out["totals"] = {
			"pledged": sum(flt(e.pledged_amount) for e in mine if e.entry_type != "In-kind"),
			"collected": sum(flt(e.paid_amount) for e in mine),
			"balance": sum(flt(e.balance_amount) for e in mine),
			"in_kind": sum(flt(e.in_kind_value) for e in mine if e.entry_type == "In-kind"),
			"entries": len(mine),
			"scope": "collected_by_me",
		}
	return out


@frappe.whitelist(methods=["POST"])
def add_collection_entry(entry_type, contributor_name=None, contributor_type="Well-wisher", contributor_mobile=None,
                         pledged_amount=0, paid_amount=0, payment_mode="Cash", reference_no=None,
                         in_kind_value=0, in_kind_details=None, for_self=0, campaign=None):
	"""for_self=1: the signed-in person pledges/pays themselves (any associate or member).
	Otherwise a member records what they collected from someone else."""
	ctx = Ctx()
	camp = _active_campaign(campaign)
	if not camp or not camp.is_active:
		frappe.throw(_("There is no open collection campaign."))
	if entry_type not in ("Pledge", "Payment", "In-kind"):
		frappe.throw(_("Unknown entry type."))
	doc = frappe.get_doc({"doctype": "SIO Collection Entry", "campaign": camp.name, "entry_type": entry_type,
	                      "unit": ctx.unit})
	if cint(for_self):
		ctx.require("pledge")
		ctx.need_member()
		doc.update({
			"contributor_name": ctx.member.full_name,
			"contributor_type": "Member" if ctx.is_member else "Associate",
			"contributor_member": ctx.member.name,
			"contributor_mobile": ctx.member.mobile,
		})
		# money paid by the person themselves is confirmed by a collector later
		paid_amount = 0
	else:
		ctx.require("collect")
		if not (contributor_name or "").strip():
			frappe.throw(_("Enter the contributor's name."))
		doc.update({
			"contributor_name": contributor_name.strip(),
			"contributor_type": contributor_type,
			"contributor_mobile": contributor_mobile,
			"collected_by": ctx.member.name if ctx.member else None,
		})
	if entry_type == "Pledge":
		doc.pledged_amount = flt(pledged_amount)
		if doc.pledged_amount <= 0:
			frappe.throw(_("Enter the pledged amount."))
	elif entry_type == "In-kind":
		doc.in_kind_value = flt(in_kind_value)
		doc.in_kind_details = in_kind_details
	if entry_type != "In-kind" and flt(paid_amount) > 0:
		doc.append("payments", {"payment_date": nowdate(), "amount": flt(paid_amount), "mode": payment_mode,
		                        "reference_no": reference_no, "received_by": doc.collected_by})
	if entry_type == "Payment" and not doc.payments:
		frappe.throw(_("Enter the amount received."))
	doc.insert(ignore_permissions=True)
	return {"name": doc.name, "status": doc.status}


@frappe.whitelist(methods=["POST"])
def add_payment(entry, amount, mode="Cash", reference_no=None):
	ctx = Ctx()
	ctx.require("collect")
	doc = frappe.get_doc("SIO Collection Entry", entry)
	mine = ctx.member and doc.collected_by == ctx.member.name
	if not mine:
		if not ctx.is_unit_admin and not ctx.is_finance:
			frappe.throw(_("Only the collector or the unit admin can add payments."), frappe.PermissionError)
		ctx.check_unit(doc.unit)
	if flt(amount) <= 0:
		frappe.throw(_("Enter the amount."))
	doc.append("payments", {"payment_date": nowdate(), "amount": flt(amount), "mode": mode,
	                        "reference_no": reference_no, "received_by": ctx.member.name if ctx.member else None})
	doc.save(ignore_permissions=True)
	return {"status": doc.status, "paid_amount": doc.paid_amount, "balance_amount": doc.balance_amount}


# --------------------------------------------------------------------------------------- expenses


@frappe.whitelist()
def expenses(status=None):
	ctx = Ctx()
	caps = ctx.capabilities()
	if not (caps["claim_expense"] or caps["approve_expense"]):
		frappe.throw(_("You are not allowed to see expenses."), frappe.PermissionError)
	filters = {}
	if status:
		filters["status"] = status
	if caps["approve_expense"]:
		pass
	elif ctx.is_unit_admin:
		filters["unit"] = ctx.unit or "__none__"
	else:
		filters["claimed_by"] = ctx.need_member().name
	rows = frappe.get_all(
		"SIO Expense Claim",
		filters=filters,
		fields=["name", "description", "category", "amount", "expense_date", "status", "claimed_by",
		        "claimed_by_name", "unit", "event", "bill", "remarks"],
		order_by="creation desc",
		limit=200,
	)
	totals = {}
	for r in rows:
		totals[r.status] = totals.get(r.status, 0) + flt(r.amount)
	return {"claims": rows, "totals": totals, "can_approve": caps["approve_expense"]}


@frappe.whitelist(methods=["POST"])
def claim_expense(description, amount, category="Other", expense_date=None, event=None, bill_data=None,
                  bill_filename=None):
	ctx = Ctx()
	ctx.require("claim_expense")
	ctx.need_member()
	if flt(amount) <= 0:
		frappe.throw(_("Enter the amount."))
	doc = frappe.get_doc(
		{
			"doctype": "SIO Expense Claim",
			"description": description,
			"amount": flt(amount),
			"category": category,
			"expense_date": expense_date or nowdate(),
			"event": event,
			"unit": ctx.unit,
			"claimed_by": ctx.member.name,
		}
	).insert(ignore_permissions=True)
	if bill_data:
		f = frappe.get_doc(
			{
				"doctype": "File",
				"file_name": bill_filename or f"{doc.name}-bill.jpg",
				"attached_to_doctype": "SIO Expense Claim",
				"attached_to_name": doc.name,
				"attached_to_field": "bill",
				"is_private": 1,
				"content": base64.b64decode(bill_data),
			}
		).insert(ignore_permissions=True)
		doc.db_set("bill", f.file_url)
	return {"name": doc.name}


@frappe.whitelist(methods=["POST"])
def set_expense_status(name, status, remarks=None, payment_mode=None):
	ctx = Ctx()
	ctx.require("approve_expense")
	if status not in ("Approved", "Rejected", "Paid"):
		frappe.throw(_("Unknown status."))
	doc = frappe.get_doc("SIO Expense Claim", name)
	doc.status = status
	if remarks:
		doc.remarks = remarks
	if payment_mode:
		doc.payment_mode = payment_mode
	doc.save(ignore_permissions=True)
	return {"status": doc.status}


# ---------------------------------------------------------------------------------------- notices


def _notices_for(ctx, limit=50):
	m = ctx.member
	args = {
		"unit": ctx.unit or "__none__",
		"role": m.member_role if m else "__none__",
		"member": m.name if m else "__none__",
		"user": ctx.user,
	}
	return frappe.db.sql(
		f"""select n.name, n.title, n.message, n.audience, n.unit, n.member_role, n.event, n.sent_on,
			n.recipient_count, n.sent_by
		from `tabSIO Notice` n
		where n.audience = 'Everyone'
			or (n.audience = 'Unit' and n.unit = %(unit)s)
			or (n.audience = 'Role' and n.member_role = %(role)s)
			or (n.audience = 'Event Registrants' and exists (select 1 from `tabSIO Event Registration` r
				where r.event = n.event and r.member = %(member)s and r.status != 'Cancelled'))
			or n.sent_by = %(user)s
		order by n.sent_on desc limit {cint(limit)}""",
		args,
		as_dict=True,
	)


@frappe.whitelist()
def notices():
	return _notices_for(Ctx())


@frappe.whitelist(methods=["POST"])
def send_notice(title, message, audience="Unit", unit=None, member_role=None, event=None, send_whatsapp=0,
                send_email=0):
	ctx = Ctx()
	ctx.require("send_notice")
	if audience in ("Everyone", "Role") and not ctx.is_admin:
		frappe.throw(_("Only district admins can send to everyone or by role."), frappe.PermissionError)
	if audience == "Unit":
		unit = unit or ctx.unit
		ctx.check_unit(unit)
	doc = frappe.get_doc(
		{
			"doctype": "SIO Notice",
			"title": title,
			"message": message,
			"audience": audience,
			"unit": unit if audience == "Unit" else None,
			"member_role": member_role if audience == "Role" else None,
			"event": event if audience == "Event Registrants" else None,
			"send_whatsapp": cint(send_whatsapp),
			"send_email": cint(send_email),
		}
	).insert(ignore_permissions=True)
	frappe.enqueue("sio_connect.api.mobile.deliver_notice", notice=doc.name, enqueue_after_commit=True)
	return {"name": doc.name, "recipients": doc.recipient_count}


def deliver_notice(notice):
	"""Background: email and the WhatsApp hook. Apps can add `sio_notice_whatsapp = "dotted.path"` in hooks."""
	doc = frappe.get_doc("SIO Notice", notice)
	members = audience_members(doc)
	if doc.send_email and members:
		emails = [e for e in frappe.get_all("SIO Member", filters={"name": ["in", members]}, pluck="email") if e]
		if emails:
			frappe.sendmail(recipients=[], bcc=emails, subject=doc.title, message=doc.message, delayed=True)
	if doc.send_whatsapp:
		for method in frappe.get_hooks("sio_notice_whatsapp"):
			frappe.get_attr(method)(doc, members)


# ---------------------------------------------------------------------------------------- members


@frappe.whitelist()
def members(q=None, status=None):
	ctx = Ctx()
	ctx.require("view_members")
	filters = {}
	scope = ctx.unit_scope()
	if scope:
		filters["unit"] = scope
	if status:
		filters["status"] = status
	or_filters = None
	if q:
		or_filters = {"full_name": ["like", f"%{q}%"], "mobile": ["like", f"%{q}%"], "name": ["like", f"%{q}%"]}
	rows = frappe.get_all(
		"SIO Member",
		filters=filters,
		or_filters=or_filters,
		fields=["name", "full_name", "mobile", "email", "member_role", "status", "unit", "campus", "course",
		        "year_of_study", "joined_on", "creation"],
		order_by="full_name asc",
		limit=300,
	)
	# people waiting for approval first
	rows.sort(key=lambda r: r.status != "Pending Approval")
	return rows


@frappe.whitelist(methods=["POST"])
def approve_member(name, action="approve", member_role="Associate"):
	ctx = Ctx()
	ctx.require("approve_members")
	doc = frappe.get_doc("SIO Member", name)
	ctx.check_unit(doc.unit)
	if action == "reject":
		doc.status = "Rejected"
	else:
		if not ctx.is_admin and member_role not in MEMBER_ROLES_UNIT_ADMIN_CAN_GIVE:
			frappe.throw(_("Only district admins can give that role."), frappe.PermissionError)
		doc.status = "Active"
		doc.member_role = member_role
	doc.save(ignore_permissions=True)
	return {"status": doc.status, "member_role": doc.member_role}
