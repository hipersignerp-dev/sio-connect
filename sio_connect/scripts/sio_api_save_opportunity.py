ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Post on the student board. Everyone can share notes, jobs and internships (with a referral or contact), ask for
# blood, and forward scholarships and exam alerts (e.g. shared from WhatsApp); leaders can post every kind. A blood request reaches everyone in the area straight away.
m = ctx["member"]
if not m:
    frappe.throw(_("Your student record is not set up yet."))
lead = bool(ctx["caps"]["send_notice"] or ctx["caps"]["manage_events"])
kind = args.get("kind")
if kind not in ("Scholarship", "Exam & Admission", "Career", "Job", "Internship", "Study Circle", "Notes", "Blood Request"):
    frappe.throw(_("Pick what kind of post this is."))
if kind == "Career" and not lead:
    frappe.throw(_("Only unit and area leaders can post this. Send it to your unit secretary."))
title = (args.get("title") or "").strip()[:140]
if not title:
    frappe.throw(_("Write a title."))
recent = frappe.db.count("SIO Opportunity", {"posted_by": m.name, "creation": [">", frappe.utils.add_to_date(
    frappe.utils.now_datetime(), hours=-1)]})
if recent >= 5 and not lead:
    frappe.throw(_("You have posted a lot in the last hour. Try again later."))
link = (args.get("link") or "").strip()
if link and not (link.startswith("http://") or link.startswith("https://")):
    link = "https://" + link
doc = frappe.get_doc({"doctype": "SIO Opportunity", "kind": kind, "title": title,
                      "details": (args.get("details") or "").strip()[:2000] or None, "link": link or None,
                      "last_date": args.get("last_date") or None, "place": (args.get("place") or "").strip() or None,
                      "blood_group": args.get("blood_group") or None,
                      "contact": (args.get("contact") or "").strip() or None, "status": "Open",
                      "area": ctx["area"] if not (lead and frappe.utils.cint(args.get("everywhere"))) else None,
                      "unit": m.unit, "posted_by": m.name}).insert(ignore_permissions=True)
data = args.get("file_data")
if data:
    if len(data) > 7000000:
        frappe.throw(_("The file is too large (5 MB at most)."))
    fname = (args.get("file_name") or "notes.pdf").replace("/", "-")[-80:]
    ext = fname.split(".")[-1].lower() if "." in fname else "pdf"
    if ext not in ("pdf", "jpg", "jpeg", "png", "doc", "docx", "ppt", "pptx"):
        frappe.throw(_("Share a PDF, image, Word or PowerPoint file."))
    f = frappe.get_doc({"doctype": "File", "file_name": "n-" + frappe.utils.generate_hash(length=10) + "-" + fname,
                        "attached_to_doctype": "SIO Opportunity", "attached_to_name": doc.name,
                        "attached_to_field": "attachment", "is_private": 0, "content": data,
                        "decode": True}).insert(ignore_permissions=True)
    frappe.db.set_value("SIO Opportunity", doc.name, "attachment", f.file_url)
if kind == "Blood Request":
    msg = (args.get("blood_group") or "") + " blood needed"
    if doc.place:
        msg = msg + " at " + doc.place
    if doc.contact:
        msg = msg + ". Contact " + doc.contact
    frappe.get_doc({"doctype": "SIO Notice", "title": "🩸 " + title, "message": msg + ". Open the student board.",
                    "audience": "Everyone", "area": ctx["area"]}).insert(ignore_permissions=True)
frappe.response["message"] = {"name": doc.name}
