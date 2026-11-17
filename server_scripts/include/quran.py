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
