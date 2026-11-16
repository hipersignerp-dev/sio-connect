# Turn rough spoken notes into clean meeting minutes with the AI service set in SIO Settings
# (Anthropic Claude or Google Gemini). The notes may be Malayalam, English or a mix, with speech errors.
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
    if ctx["scope"] and m.unit != ctx["scope"]:
        frappe.throw(_("This meeting is for another unit."), frappe.PermissionError)
    meeting = ("Meeting: " + (m.topic or "") + " (" + (m.meeting_type or "") + "), " + (m.unit or "") + " unit, "
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
            "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + key,
            headers={"Content-Type": "application/json"},
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
