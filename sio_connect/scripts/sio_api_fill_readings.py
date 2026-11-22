ctx = run_script("SIO lib ctx").sio_ctx
if ctx["user"] == "Guest":
    frappe.throw(_("Please sign in."), frappe.AuthenticationError)
args = frappe.form_dict
SCOPE_UNITS = ctx["units"]  # None = every unit, else the units this person may see


def in_scope(u):
    return SCOPE_UNITS is None or (u in SCOPE_UNITS)


def scope_list():
    return SCOPE_UNITS or ["__none__"]

# Admins: fill the Arabic text, Malayalam translation and recitation audio of every ayah reading now
# (normally it fills itself the first time each ayah is shown).
# --- Quran text helper (shared): fill Arabic, Malayalam and recitation audio for an ayah reading once ---
def fill_ayah(r):
    # r: dict with name, kind, reference, text_en. Reference like "Qur'an 94:5-6". Saves and updates r.
    if r.get("kind") != "Ayah" or r.get("filled_from_quran_api"):
        return r
    ref = (r.get("reference") or "").replace("Qur'an", "").replace("Quran", "").strip()
    if ":" not in ref:
        return r
    surah = ref.split(":")[0].strip()
    ayahs = ref.split(":")[1].strip()
    first = ayahs.split("-")[0].strip()
    last = ayahs.split("-")[1].strip() if "-" in ayahs else first
    if not (surah.isdigit() and first.isdigit() and last.isdigit()):
        return r
    ar = []
    ml = []
    en = []
    audio = []
    for n in range(int(first), min(int(last), int(first) + 5) + 1):
        try:
            res = frappe.make_get_request("https://api.alquran.cloud/v1/ayah/" + surah + ":" + str(n)
                                          + "/editions/quran-uthmani,ml.abdulhameed,en.sahih")
        except Exception:
            return r  # try again next time
        data = (res or {}).get("data") or []
        if len(data) < 3:
            return r
        ar.append(data[0].get("text") or "")
        ml.append(data[1].get("text") or "")
        en.append(data[2].get("text") or "")
        audio.append("https://cdn.islamic.network/quran/audio/128/ar.alafasy/" + str(data[0].get("number")) + ".mp3")
    upd = {"text_ar": " ".join(ar), "text_ml": " ".join(ml), "audio": "\n".join(audio), "filled_from_quran_api": 1}
    if not (r.get("text_en") or "").strip() or r.get("text_en") == "…":
        upd["text_en"] = " ".join(en)
    frappe.db.set_value("SIO Daily Reading", r.get("name"), upd)
    for k in upd:
        r[k] = upd[k]
    return r
# --- end Quran text helper ---
if SCOPE_UNITS is not None:
    frappe.throw(_("You are not allowed to do this."), frappe.PermissionError)
rows = frappe.get_all("SIO Daily Reading", filters={"kind": "Ayah", "filled_from_quran_api": 0},
                      fields=["name", "kind", "reference", "text_en", "filled_from_quran_api"], limit=40)
done = 0
for r in rows:
    fill_ayah(r)
    if r.get("filled_from_quran_api"):
        done = done + 1
frappe.response["message"] = {"filled": done, "left": len(rows) - done}
