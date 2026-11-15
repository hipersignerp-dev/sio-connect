<p align="center"><img src="sio_connect/public/images/sio-logo.png" alt="SIO" width="120"></p>

# SIO Connect

Student organisation management inside **Hipersign ERP**, with a phone app for every member.
Weekly meetings and attendance, members and new associates, events and registrations, the Ramadan
collection (pledges, payments, in-kind), expense claims with approval, and updates to members.

This repo has two parts:

| Folder | What it is |
| --- | --- |
| `sio_connect/` | Frappe app: the SIO doctypes, roles, workspace and the API the phone app uses |
| `mobile/` | Flutter phone app (Android and iOS), built like the Hipersign mobile app, in SIO colours |

## Everyone gets their own app

Each person signs in with their own account and sees only what their role allows. The app asks ERP
what the person may do (`capabilities`) and builds its tabs, the **+** menu and every screen from that.

| Role (on SIO Member) | What they see in the app |
| --- | --- |
| **Associate** (self-registered, waiting approval or approved) | Home, Events, Give (own pledges), updates, profile |
| **Member** | + Meetings with RSVP, own attendance, collection entries they collect, expense claims |
| **Unit Secretary / Unit President** | + mark attendance and minutes, schedule meetings, approve new associates in their unit, unit collection totals, send updates to the unit |
| **Finance** | + collection totals for all units, approve and pay expense claims |
| **District Admin** | Everything, all units, any role, updates to everyone |

The server checks every request; hiding a screen in the app is only for convenience.

## Sign-up and fingerprint sign-in

1. **Register as an associate** from the app: name, mobile, email, password, unit, college and course.
   This creates an ERP user (website user, no desk) with the *SIO Associate* role and an **SIO Member**
   record with status *Pending Approval*.
2. The unit president or secretary approves them in the app (More → Students & members) or in the desk,
   and can make them a Member. ERP roles follow the member's role and status automatically.
3. **Fingerprint / face sign-in**: after the first password sign-in the app offers to turn it on. ERP
   issues a long random device token; only its SHA-256 hash is stored (doctype **SIO Device Token**).
   The phone keeps the token in the Android Keystore / iOS Keychain and releases it only after the
   fingerprint check, then exchanges it for a fresh session. Tick **Revoked** on a phone's record to
   block it. Signing out also turns it off. The phone PIN works as a fallback.

## Install the ERP app

```bash
cd ~/frappe-bench
bench get-app https://github.com/hipersignerp-dev/sio-connect
bench --site <your-site> install-app sio_connect
bench --site <your-site> migrate
```

Installing creates:

- doctypes **SIO Unit, SIO Member, SIO Meeting** (with attendance), **SIO Event, SIO Event Registration,
  SIO Collection Campaign, SIO Collection Entry** (with payments), **SIO Expense Claim, SIO Notice,
  SIO Device Token**
- roles **SIO Associate, SIO Member** (phone only), **SIO Unit Admin, SIO Finance, SIO Admin** (desk too)
- the **SIO Connect** workspace

Then, in the desk:

1. Add the **units** (SIO Unit).
2. Create an **SIO Member** for each office bearer, link their **User**, set the role
   (Unit President, Finance, District Admin) and status *Active*.
3. Create the **Collection Campaign** (e.g. *Ramadan Collection 1448*, target, dates, Active).
4. Optional: in System Settings turn on *Allow Login using Mobile Number* so people can sign in with
   their mobile as well as email.

WhatsApp: updates can be sent on WhatsApp through your provider. Add
`sio_notice_whatsapp = "your_app.module.send"` to a custom app's hooks; it is called with the notice
and the list of member IDs.

## Phone app

The app talks to `https://nexus365.hipersignerp.cloud` by default (changeable on the sign-in screen
under *Server*).

### Download

Every push to `main` builds the APK with GitHub Actions and publishes it as the
[latest release](../../releases/latest).

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

- `auth.units`, `auth.register` (guest), `auth.enable_biometric`, `auth.login_with_device` (guest),
  `auth.disable_biometric`
- `mobile.me`, `home`, `meetings`, `meeting`, `rsvp`, `save_attendance`, `schedule_meeting`,
  `events`, `event`, `register_event`, `collection`, `add_collection_entry`, `add_payment`,
  `expenses`, `claim_expense`, `set_expense_status`, `notices`, `send_notice`, `members`,
  `approve_member`, `update_my_profile`

## License

MIT
