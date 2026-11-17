# Admins: fill the Arabic text, Malayalam translation and recitation audio of every ayah reading now
# (normally it fills itself the first time each ayah is shown).
# @include quran
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
