# Continue with Google (guest). Known email: signs in and returns a token for this phone. New email: returns
# their Google name/email so the app can show the short sign-up form (register with google_token).
# --- Google sign-in helpers (shared) ---
GOOGLE_WEB_CLIENT = "280665319397-ggctdep18o9afufgc2a7nr3serc2bll0.apps.googleusercontent.com"


def google_identity(id_token):
    # Ask Google whether this ID token is genuine and meant for our app; returns email and name.
    if not id_token:
        frappe.throw(_("Google sign-in failed. Try again."))
    try:
        info = frappe.make_get_request("https://oauth2.googleapis.com/tokeninfo?id_token=" + id_token)
    except Exception:
        info = None
    if not info or info.get("aud") != GOOGLE_WEB_CLIENT or str(info.get("email_verified")).lower() != "true" \
            or not info.get("email"):
        frappe.throw(_("Google sign-in could not be verified. Try again."))
    return {"email": info.get("email").strip().lower(), "name": info.get("name") or "",
            "picture": info.get("picture") or ""}


def issue_token(user_name, device):
    # A sign-in token for this phone (same mechanism as fingerprint sign-in): api_key:api_secret.
    u = frappe.get_doc("User", user_name)
    if not u.api_key:
        u.api_key = frappe.utils.generate_hash(length=15)
    secret = frappe.utils.generate_hash(length=15)
    u.api_secret = secret
    u.save(ignore_permissions=True)
    frappe.get_doc({"doctype": "SIO Device Token", "user": user_name, "device_name": (device or "Phone")[:140],
                    "token_hash": frappe.utils.sha256_hash(secret),
                    "last_used": frappe.utils.now_datetime()}).insert(ignore_permissions=True)
    return u.api_key + ":" + secret
# --- end Google sign-in helpers ---
f = frappe.form_dict
g = google_identity(f.get("id_token"))
user = frappe.db.get_value("User", {"name": g["email"]}, ["name", "enabled"], as_dict=True)
if not user:
    m = frappe.db.get_value("SIO Member", {"email": g["email"], "user": ["is", "set"]}, "user")
    if m:
        user = frappe.db.get_value("User", m, ["name", "enabled"], as_dict=True)
if user:
    if not user.enabled:
        frappe.throw(_("This account is turned off. Contact your unit."))
    frappe.response["message"] = {"token": issue_token(user.name, f.get("device_name")), "user": user.name}
else:
    frappe.response["message"] = {"new": 1, "email": g["email"], "full_name": g["name"]}
