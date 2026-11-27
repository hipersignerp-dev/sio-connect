"""Natural Malayalam audio for the daily readings.

Phones read Malayalam badly with their built-in voice (many have no Malayalam voice at all), so the server makes
a proper recording once per reading with Gemini text-to-speech (Malayalam, ml-IN), using the Gemini key in
SIO Settings > AI API key. The WAV file is saved on the reading (field ml_audio) and reused by everyone. If the
Malayalam text changes, a new recording is made the next time someone listens.
"""

import base64
import hashlib
import io
import wave

import frappe
import requests

# tried in order; the first model the key can use wins (names change as Google releases new ones)
MODELS = ["gemini-3.1-flash-tts-preview", "gemini-2.5-flash-preview-tts"]
VOICE = "Kore"  # calm, clear
RATE = 24000  # Gemini returns 16-bit mono PCM at 24 kHz


def _text(r):
	parts = []
	if (r.get("text_ml") or "").strip():
		parts.append(r["text_ml"].strip())
	if (r.get("lesson_ml") or "").strip():
		parts.append("ഇന്നത്തെ പാഠം. " + r["lesson_ml"].strip())
	return "\n\n".join(parts)


def _key():
	try:
		return frappe.get_single("SIO Settings").get_password("ai_api_key", raise_exception=False)
	except Exception:
		return None


def _speak(text):
	key = _key()
	if not key:
		frappe.throw("Add the Gemini API key in SIO Settings first.")
	prompt = (
		"Read the following Malayalam text aloud in natural, fluent Malayalam (Kerala accent), "
		"warmly and clearly, at a calm pace, like a kind teacher. Read every word exactly as written; "
		"do not translate or add anything.\n\n" + text
	)
	body = {
		"contents": [{"parts": [{"text": prompt}]}],
		"generationConfig": {
			"responseModalities": ["AUDIO"],
			"speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": VOICE}}},
		},
	}
	last = None
	for model in MODELS:
		r = requests.post(
			f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
			headers={"x-goog-api-key": key},  # in a header, so the key never shows up in a logged URL
			json=body,
			timeout=120,
		)
		if r.status_code == 200:
			try:
				data = r.json()["candidates"][0]["content"]["parts"][0]["inlineData"]["data"]
				return base64.b64decode(data)
			except (KeyError, IndexError, ValueError):
				last = "no audio in the reply"
				continue
		last = f"{model}: {r.status_code} {r.text[:200]}"
		if r.status_code in (401, 403):
			break  # the key itself is the problem
	frappe.log_error(title="SIO Malayalam audio failed", message=last or "")
	frappe.throw("Couldn't make the Malayalam audio right now.")


def _wav(pcm):
	out = io.BytesIO()
	with wave.open(out, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes(pcm)
	return out.getvalue()


def make(reading, force=False):
	r = frappe.db.get_value(
		"SIO Daily Reading", reading, ["name", "text_ml", "lesson_ml", "ml_audio", "ml_audio_for"], as_dict=True
	)
	if not r:
		frappe.throw("Reading not found")
	text = _text(r)
	if not text:
		return None
	sig = hashlib.sha1(text.encode()).hexdigest()[:16]
	if r.ml_audio and r.ml_audio_for == sig and not force:
		return r.ml_audio
	lock = f"sio_ml_audio_{reading}"
	if frappe.cache.get_value(lock):
		frappe.throw("The Malayalam audio is being made. Try again in a few seconds.")
	frappe.cache.set_value(lock, 1, expires_in_sec=180)
	try:
		wav = _wav(_speak(text))
		f = frappe.get_doc(
			{
				"doctype": "File",
				"file_name": f"ml-{reading}-{sig}.wav",
				"attached_to_doctype": "SIO Daily Reading",
				"attached_to_name": reading,
				"attached_to_field": "ml_audio",
				"is_private": 0,
				"content": wav,
			}
		).insert(ignore_permissions=True)
		frappe.db.set_value(
			"SIO Daily Reading", reading, {"ml_audio": f.file_url, "ml_audio_for": sig}, update_modified=False
		)
		frappe.db.commit()
		return f.file_url
	finally:
		frappe.cache.delete_value(lock)


@frappe.whitelist()
def ml_audio(reading):
	"""The Malayalam recording for a reading (made on first use). Any signed-in member."""
	if frappe.session.user == "Guest":
		frappe.throw("Please sign in", frappe.PermissionError)
	return {"url": make(reading)}


@frappe.whitelist()
def make_all(force=0):
	"""Admins: record every active reading now (runs in the background)."""
	if not set(frappe.get_roles()) & {"System Manager", "SIO Admin"}:
		frappe.throw("Not allowed", frappe.PermissionError)
	frappe.enqueue("sio_connect.tts._make_all", queue="long", timeout=3600, force=frappe.utils.cint(force))
	return {"queued": 1}


def _make_all(force=0):
	for name in frappe.get_all("SIO Daily Reading", filters={"active": 1}, pluck="name"):
		try:
			make(name, force=bool(force))
		except Exception:
			frappe.log_error(title=f"SIO Malayalam audio {name}")
