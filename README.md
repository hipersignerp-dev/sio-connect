<p align="center"><img src="sio_connect/public/images/sio-logo.png" alt="SIO" width="120"></p>

# SIO Connect

Student organisation management inside **Hipersign ERP**, with a phone app for every member.
Weekly meetings and attendance, members and new associates, events and registrations, collections
(Ramadan Collection, Baithul Mal, Zakat, ...: offers, payments and items), expense claims with approval,
and updates to members.

**Live site:** https://siootp.hipersignerp.cloud (built with the server-script install below; desk workspace
*SIO Connect*). The phone app points there by default.

This repo has three parts:

| Folder | What it is |
| --- | --- |
| `sio_connect/` | Frappe app: the SIO doctypes, roles, workspace and the API the phone app uses (install with bench) |
| `server_scripts/` | The same API and rules as Server Scripts, for a site with no bench access (how the live site is built) |
| `mobile/` | Flutter phone app (Android and iOS), built like the Hipersign mobile app, in SIO colours |

## Everyone gets their own app

Each person signs in with their own account and sees only what their role allows. The app asks ERP
what the person may do (`capabilities`) and builds its tabs, the **+** menu and every screen from that.

| Role (on SIO Member) | What they see in the app |
| --- | --- |
| **Associate** (self-registered, waiting approval or approved) | Home, Events, Give (own offers), updates, profile |
| **Member** | + Meetings with RSVP, own attendance, collection entries they collect, expense claims |
| **Unit Secretary / Unit President** | + mark attendance and minutes, schedule meetings, approve new associates in their unit, unit collection totals, send updates to the unit |
| **Finance** | + collection totals for all units, approve and pay expense claims |
| **District Admin** | Everything, all units, any role, updates to everyone |

The server checks every request; hiding a screen in the app is only for convenience.

## Collections

Any number of collections can be open at once, each with a type (Ramadan Collection, Baithul Mal, Zakat,
Relief Fund, Other), an optional target and dates, and optionally limited to one unit. Each entry is:

- **Offer**: someone promises an amount and pays later; status goes *Offered → Part Paid → Paid* as the
  collector records money received,
- **Payment**: paid on the spot (*Paid*),
- **Items**: food kits, clothes and so on, with an approximate value (*Items Received*).

Everyone can give their own offer from the app; members record what they collect from others; unit admins
see their unit's totals; finance and district admins see all units.

## Sign-up and fingerprint sign-in

1. **Register as an associate** from the app: name, mobile, email, password, unit, college and course.
   This creates an ERP user (website user, no desk) with the *SIO Associate* role and an **SIO Member**
   record with status *Pending Approval*.
2. The unit president or secretary approves them in the app (More → Students & members) or in the desk,
   and can make them a Member. ERP roles follow the member's role and status automatically.
3. **Fingerprint / face sign-in**: after the first password sign-in the app offers to turn it on. ERP
   gives the person an API key and a fresh secret; the phone keeps them in the Android Keystore / iOS
   Keychain and releases them only after the fingerprint check, then sends them as
   `Authorization: token key:secret`. Each phone is listed in **SIO Device Token**; tick **Revoked** to
   block it (the secret is replaced). Signing out also turns it off. One secret per person, so turning
   it on for a new phone switches it off on the old one. The phone PIN works as a fallback.

## Install on a site

### Option A: server scripts (no bench access; how siootp.hipersignerp.cloud is built)

Needs `server_script_enabled` on the site. Create, in this order:

1. Module Def **SIO Connect** (custom) and the five roles (*SIO Associate* and *SIO Member* without desk
   access; *SIO Unit Admin*, *SIO Finance*, *SIO Admin* with desk access).
2. The 12 DocTypes as custom DocTypes from `sio_connect/sio_connect/doctype/*/*.json` (set `custom: 1`).
   Order: SIO Unit (without president/secretary, add them last), SIO Member, the two child tables, then
   the rest.
3. The 43 Server Scripts: `python3 server_scripts/build.py` writes one JSON per script to
   `server_scripts/dist/` (5 library scripts, 25 API scripts with the same method names as the Python
   app, 13 document event scripts).
4. Point the workspace **SIO Connect** at the doctypes.

Sandbox notes, learned on Frappe 16: no imports, no `str.format`, no `+=` on dict items, no `a, b = x`
unpacking; each script has its own `frappe.flags`, so a library script's result is read from the return
value: `ctx = run_script("SIO lib ctx").sio_ctx`.

### Option B: bench app

```bash
cd ~/frappe-bench
bench get-app https://github.com/hipersignerp-dev/sio-connect
bench --site <your-site> install-app sio_connect
bench --site <your-site> migrate
```

Installing creates:

- doctypes **SIO Unit, SIO Member, SIO Meeting** (with attendance), **SIO Event, SIO Event Registration,
  SIO Collection, SIO Collection Entry** (with payments), **SIO Expense Claim, SIO Notice,
  SIO Device Token**
- roles **SIO Associate, SIO Member** (phone only), **SIO Unit Admin, SIO Finance, SIO Admin** (desk too)
- the **SIO Connect** workspace

Then, in the desk:

1. Add the **units** (SIO Unit).
2. Create an **SIO Member** for each office bearer, link their **User**, set the role
   (Unit President, Finance, District Admin) and status *Active*.
3. Create the **Collections** that are open (SIO Collection: e.g. *Ramadan Collection 1448*, *Baithul Mal
   2026-27*; type, optional target and dates, optional unit, Open ticked). Several can be open at once.
4. Optional: in System Settings turn on *Allow Login using Mobile Number* so people can sign in with
   their mobile as well as email.

WhatsApp: updates can be sent on WhatsApp through your provider. Add
`sio_notice_whatsapp = "your_app.module.send"` to a custom app's hooks; it is called with the notice
and the list of member IDs.

## Phone app

The app talks to `https://siootp.hipersignerp.cloud` by default (changeable on the sign-in screen
under *Server*).

### Download

Every push to `main` builds the APK with GitHub Actions and publishes it as the
[latest release](../../releases/latest).

### Tests

```bash
cd mobile && flutter test                                   # widgets and role-based tabs
flutter test test_live --dart-define=SIO_PASSWORD=...        # the app's API client against the live site
python3 server_scripts/e2e_test.py https://siootp.hipersignerp.cloud PASSWORD   # 35 checks, 3 roles
```

The live tests use `sio.test.president@example.com` and `sio.test.finance@example.com` in unit Feroke;
`e2e_test.py` registers a new test associate each run and adds test entries, so run it on a test site.

### Build it yourself

```bash
cd mobile
flutter pub get
flutter test
flutter build apk --release
```

For release signing, add these repository secrets and the workflow signs the APK with your key
(otherwise it uses a debug key, fine for testing): `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.

### Code map

| File | What it does |
| --- | --- |
| `lib/api.dart` | Frappe calls, password sign-in (`device=mobile`), session handling |
| `lib/biometric.dart` | Fingerprint check and the secure-storage device token |
| `lib/app_state.dart` | Who is signed in, their capabilities, lock/unlock |
| `lib/theme.dart` | SIO colours on the Hipersign layout (panels, tiles, chips) |
| `lib/screens/home_shell.dart` | Bottom bar and **+** menu, built from the person's capabilities |
| `lib/screens/*` | Home, meetings, events, collection, expenses, updates, members, more |

## API (for reference)

All under `sio_connect.api`:

- `auth.units`, `auth.register` (guest), `auth.enable_biometric`, `auth.disable_biometric`
- `mobile.me`, `home`, `meetings`, `meeting`, `rsvp`, `save_attendance`, `schedule_meeting`,
  `events`, `event`, `register_event`, `collection`, `add_collection_entry`, `add_payment`,
  `expenses`, `claim_expense`, `set_expense_status`, `notices`, `send_notice`, `members`,
  `approve_member`, `update_my_profile`

## License

MIT
