ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Turn rough spoken notes into clean meeting minutes with the AI service set in SIO Settings
# (Anthropic Claude or Google Gemini). The notes may be Malayalam, English or a mix, with speech errors.
# --- meeting helpers (shared) ---
# A meeting is for one unit (unit set) or for the whole area (area set, unit empty). For area meetings
# "invite" says who is asked to come.
INVITE_ROLES = {
    "Unit leaders": ["Unit President", "Unit Secretary", "Finance", "Area Admin"],
    "All members": ["Unit President", "Unit Secretary", "Finance", "Area Admin", "Member"],
    "Members & workers": ["Unit President", "Unit Secretary", "Finance", "Area Admin", "Member", "Worker"],
    "Everyone": ["Unit President", "Unit Secretary", "Finance", "Area Admin", "Member", "Worker", "Associate"],
}


def is_area_meeting(m):
    return bool(m.get("area")) and not m.get("unit")


def area_invitees(area, invite):
    roles = INVITE_ROLES.get(invite or "Unit leaders") or INVITE_ROLES["Unit leaders"]
    units = frappe.get_all("SIO Unit", filters={"district": area}, pluck="name")
    rows = frappe.get_all("SIO Member", filters={"status": "Active", "member_role": ["in", roles]},
                          fields=["name", "full_name", "unit", "member_role", "photo"], order_by="full_name asc")
    return [r for r in rows if (not r.unit) or r.unit in units]


def invited_to(m, member):
    # can this member (a dict/doc with name, unit, member_role) see / reply to meeting m?
    if not member:
        return False
    if not is_area_meeting(m):
        return m.get("unit") == member.unit
    roles = INVITE_ROLES.get(m.get("invite") or "Unit leaders") or INVITE_ROLES["Unit leaders"]
    if member.member_role not in roles:
        return False
    if not member.unit:
        return True
    return frappe.db.get_value("SIO Unit", member.unit, "district") == m.get("area")


def can_manage_meeting(m):
    # schedule / edit / mark / write the summary
    if is_area_meeting(m):
        return ctx["caps"]["schedule_area_meeting"] and (SCOPE_UNITS is None or m.get("area") == ctx["area"])
    return ctx["caps"]["schedule_meeting"] and in_scope(m.get("unit"))


def can_see_meeting(m):
    if SCOPE_UNITS is None:
        return True
    if is_area_meeting(m):
        return can_manage_meeting(m) or invited_to(m, ctx["member"])
    return in_scope(m.get("unit"))


def meeting_place(m):
    if is_area_meeting(m):
        return m.get("area") + " Area"
    return m.get("unit")
# --- end meeting helpers ---
if not ctx["caps"]["schedule_meeting"]:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
notes = (args.get("notes") or "").strip()
if len(notes) < 10:
    frappe.throw(_("Say or type a few lines about the meeting first."))
if len(notes) > 20000:
    frappe.throw(_("The notes are too long. Keep them under 20,000 characters."))
lang = "Malayalam" if args.get("language") == "Malayalam" else "English"
if lang == "Malayalam":
    heads = ("സംഗ്രഹം: രണ്ടോ മൂന്നോ വാക്യങ്ങൾ.\n\nചർച്ച ചെയ്തവ:\n- കാര്യം\n\nതീരുമാനങ്ങൾ:\n- തീരുമാനം\n\n"
             "ചുമതലകൾ:\n- ആര്: എന്ത് (എപ്പോഴേക്ക്)")
else:
    heads = ("Summary: two or three sentences.\n\nDiscussed:\n- point\n\nDecisions:\n- decision\n\n"
             "Action points:\n- who: what (by when)")
meeting = ""
if args.get("name"):
    m = frappe.get_doc("SIO Meeting", args.get("name"))
    if not can_manage_meeting(m):
        frappe.throw(_("This meeting is not yours to write up."), frappe.PermissionError)
    meeting = ("Meeting: " + (m.topic or "") + " (" + (m.meeting_type or "") + "), " + (meeting_place(m) or "") + ", "
               + str(m.meeting_date or "") + ". Agenda: " + (m.agenda or "not given") + ".\n\n")
settings = frappe.get_doc("SIO Settings")
key = settings.get_password("ai_api_key", raise_exception=False) if settings.get("ai_api_key") else None
if not key:
    frappe.throw(_("AI summary is not set up yet. Add an AI API key in SIO Settings."))
provider = settings.get("ai_provider") or "Anthropic Claude"
system = ("You write meeting minutes for SIO (Students Islamic Organisation of India), a student organisation. "
          "The user dictated rough notes by voice, so they may contain speech-recognition mistakes, Manglish, "
          "repetition and broken sentences. Write clean, correct minutes in " + lang + ". "
          "Fix obvious recognition errors from context, but never invent people, numbers, dates, topics or "
          "decisions that are not in the notes. Keep names as spoken. Use this plain-text layout, leaving out any "
          "section with nothing in it, and write the headings in " + lang + " too:\n"
          + heads + "\n\n"
          "Reply with the minutes only, no preamble and no markdown symbols other than '- ' bullets.")
user = meeting + "Rough notes:\n" + notes
out = None
try:
    if provider == "Google Gemini":
        model = settings.get("ai_model") or "gemini-2.5-flash"
        r = frappe.make_post_request(
            "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent",
            headers={"Content-Type": "application/json", "x-goog-api-key": key},
            data=json.dumps({"systemInstruction": {"parts": [{"text": system}]},
                             "contents": [{"role": "user", "parts": [{"text": user}]}]}))
        out = r["candidates"][0]["content"]["parts"][0]["text"]
    else:
        model = settings.get("ai_model") or "claude-haiku-5-5"
        r = frappe.make_post_request(
            "https://api.anthropic.com/v1/messages",
            headers={"x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json"},
            data=json.dumps({"model": model, "max_tokens": 2000, "system": system,
                             "messages": [{"role": "user", "content": user}]}))
        out = "".join([b.get("text", "") for b in r.get("content", []) if b.get("type") == "text"])
except Exception as e:
    frappe.log_error("SIO AI summary failed", str(e))
    frappe.throw(_("The AI service did not answer. Check the API key in SIO Settings, or try again."))
if not (out or "").strip():
    frappe.throw(_("The AI service returned nothing. Try again."))
frappe.response["message"] = {"summary": out.strip()}
