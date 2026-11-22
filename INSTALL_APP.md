# Installing the sio_connect Frappe app on siootp.hipersignerp.cloud

The SIO DocTypes already live on the site (custom DocTypes); the app adds the code. Installing it changes
nothing for users until the switch-over (step 4), because:

* it has no DocTypes of its own (module "SIO Core" is empty), so it cannot overwrite site data;
* its document events, scheduled jobs and permission rules stay off until SIO Settings > use_app_code is ticked;
* its API methods have the same paths as the Server Scripts, and an enabled Server Script always wins.

What it adds at once: **push notifications** (every SIO Notice is pushed through Firebase, once the key is in).

## 1. Press: a bench group of its own (client sites untouched)
1. Apps > New app: GitHub `hipersignerp-dev/sio-connect`, branch `main` (app name `sio_connect`).
2. Bench groups > New: copy the apps and versions of `bench-0001` (frappe, erpnext, frappe_assistant_core,
   hipersign_branding) and add `sio_connect`. Deploy.
3. Move `siootp.hipersignerp.cloud` to the new group (takes a backup; a few minutes of downtime).
4. Site > Apps > Install `sio_connect`.

## 2. Firebase key (push)
Firebase console > Project settings > Service accounts > Generate new private key. Open
`/app/sio-settings`, paste the whole file into **Firebase service account**, Save. Never send the file to anyone.
Test: `/api/method/sio_connect.api.check.push_test` while signed in (sends to your own phone).

## 3. Check the app's copy of the code
`/api/method/sio_connect.api.check.run?method=mobile.home` should answer like the phone's home screen.

## 4. Switch over (and back)
Switch: tick SIO Settings > use_app_code and disable the "SIO ..." Server Scripts (not "SIO deployer").
Back: untick it and enable them again. Both are instant.

## Updating
`server_scripts/` stays the source. After changing it: `python3 server_scripts/build.py && python3 tools/make_app.py`,
commit, then deploy the bench group in Press (and, while still on Server Scripts, the "SIO deploy" note).
