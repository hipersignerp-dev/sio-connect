# Self sign-up as an Associate (guest). The unit admin approves later. Rate limited on the script.
# With google_token (Continue with Google) the email comes from Google, no password is needed, and a sign-in
# token for this phone is returned.
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
full_name = (f.get("full_name") or "").strip()
mobile = "".join([c for c in (f.get("mobile") or "") if c.isdigit() or c == "+"])
email = (f.get("email") or "").strip().lower()
password = f.get("password") or ""
via_google = bool(f.get("google_token"))
if via_google:
    email = google_identity(f.get("google_token"))["email"]
    password = frappe.utils.generate_hash(length=24)
unit = f.get("unit") or None
digits = "".join([c for c in mobile if c.isdigit()])
if len(full_name) < 3:
    frappe.throw(_("Enter your full name."))
if len(digits) < 10:
    frappe.throw(_("Enter a valid mobile number."))
if "@" not in email or "." not in email.split("@")[-1]:
    frappe.throw(_("Enter a valid email address."))
if len(password) < 8:
    frappe.throw(_("Password must be at least 8 characters."))
if unit and not frappe.db.exists("SIO Unit", {"name": unit, "active": 1}):
    frappe.throw(_("Pick your unit from the list."))
existing = frappe.db.get_value("SIO Member", {"mobile": mobile}, ["name", "user"], as_dict=True)
if frappe.db.exists("User", email) or (existing and existing.user):
    frappe.throw(_("This email or mobile is already registered. Sign in, or use Forgot password."))

parts = full_name.split(" ", 1)
user = frappe.get_doc({
    "doctype": "User",
    "email": email,
    "first_name": parts[0],
    "last_name": parts[1] if len(parts) > 1 else "",
    "mobile_no": mobile,
    "enabled": 1,
    "send_welcome_email": 0,
    "user_type": "Website User",
    "new_password": password,
    "roles": [{"role": "SIO Associate"}],
})
user.insert(ignore_permissions=True)

if existing:
    # added earlier by the unit admin: this sign-up becomes their login, keeping role and status
    member = frappe.get_doc("SIO Member", existing.name)
    member.user = user.name
    member.email = email
    for k in ("campus", "course", "home_town", "latitude", "longitude", "location_note"):
        if f.get(k) and not member.get(k):
            member.set(k, f.get(k))
    member.save(ignore_permissions=True)
else:
    member = frappe.get_doc({
        "doctype": "SIO Member",
        "full_name": full_name,
        "mobile": mobile,
        "email": email,
        "user": user.name,
        "member_role": "Associate",
        "status": "Pending Approval",
        "unit": unit,
        "campus": f.get("campus"),
        "course": f.get("course"),
        "year_of_study": f.get("year_of_study") or "",
        "home_town": f.get("home_town"),
        "latitude": frappe.utils.flt(f.get("latitude")) or None,
        "longitude": frappe.utils.flt(f.get("longitude")) or None,
        "location_note": f.get("location_note") or None,
        "invited_by": frappe.db.get_value("SIO Member", {"username": (f.get("invite") or "").strip().lower().lstrip("@")},
                                          "name") if (f.get("invite") or "").strip() else None,
    })
    member.insert(ignore_permissions=True)
out = {"user": user.name, "member": member.name, "status": member.status}
if via_google:
    out["token"] = issue_token(user.name, f.get("device_name"))
frappe.response["message"] = out
