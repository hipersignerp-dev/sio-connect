if not ctx["member"]:
    frappe.throw(_("No member record for this account."))
m = frappe.get_doc("SIO Member", ctx["member"].name)
for field in ("campus", "course", "home_town", "year_of_study", "profession", "workplace", "current_city", "mentor_topics"):
    if args.get(field) is not None:
        m.set(field, (args.get(field) or "").strip()[:300] or None)
if args.get("life_stage") is not None:
    m.life_stage = args.get("life_stage") if args.get("life_stage") in ("School", "College", "Working", "Other") else None
if args.get("phone_visibility") in ("Leaders only", "Friends", "My unit", "All members"):
    m.phone_visibility = args.get("phone_visibility")
if args.get("hide_games") is not None:
    m.hide_games = 1 if frappe.utils.cint(args.get("hide_games")) else 0

# house location: latitude / longitude from the phone, and an address or landmark
if args.get("latitude") not in (None, "") and args.get("longitude") not in (None, ""):
    lat = frappe.utils.flt(args.get("latitude"))
    lng = frappe.utils.flt(args.get("longitude"))
    if -90 <= lat <= 90 and -180 <= lng <= 180:
        m.latitude = lat
        m.longitude = lng
elif args.get("clear_location"):
    m.latitude = None
    m.longitude = None
if args.get("location_note") is not None:
    m.location_note = args.get("location_note") or None
if args.get("unit") and m.status == "Pending Approval":
    m.unit = args.get("unit")
m.save(ignore_permissions=True)
frappe.response["message"] = run_script("SIO lib ctx").sio_ctx["me"]
