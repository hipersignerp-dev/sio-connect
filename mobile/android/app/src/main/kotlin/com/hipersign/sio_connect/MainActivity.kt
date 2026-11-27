package com.hipersign.sio_connect

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is needed for the fingerprint prompt (local_auth)
class MainActivity : FlutterFragmentActivity() {
    // text shared into the app (Share > SIO Connect), waiting for Dart to pick it up
    private var sharedText: String? = null
    private var shareChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        takeShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (takeShare(intent)) shareChannel?.invokeMethod("shared", null)
    }

    private fun takeShare(i: Intent?): Boolean {
        if (i?.action == Intent.ACTION_SEND && i.type?.startsWith("text/") == true) {
            val t = i.getStringExtra(Intent.EXTRA_TEXT)
            val subject = i.getStringExtra(Intent.EXTRA_SUBJECT)
            if (!t.isNullOrBlank()) {
                sharedText = if (!subject.isNullOrBlank() && !t.contains(subject)) subject + "\n" + t else t
                return true
            }
        }
        return false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hipersign.sio_connect/share")
        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "take" -> {
                    result.success(sharedText)
                    sharedText = null
                }
                else -> result.notImplemented()
            }
        }
        // in-app updates: Dart's UpdateService asks this to download and install a new APK
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hipersign.sio_connect/updater")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "install" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.success("error")
                        } else {
                            UpdateInstaller.install(this, url, call.argument<String>("name") ?: "SIO-Connect.apk", result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        // A sound the person picked for prayer reminders: hand the system a content:// link it may read,
        // so the notification can play it (a plain file path would be refused).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hipersign.sio_connect/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "uri" -> {
                        try {
                            val path = call.argument<String>("path") ?: ""
                            val uri = androidx.core.content.FileProvider.getUriForFile(
                                this, "${packageName}.updates", java.io.File(path))
                            for (pkg in listOf("com.android.systemui", "android")) {
                                grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            result.success(uri.toString())
                        } catch (e: Exception) {
                            result.error("uri", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    
        // Prayer reminders must ring while the app is closed. Many phones (Vivo, Oppo, Realme, Xiaomi…)
        // stop an app's alarms to save battery unless the person allows it. This lets Dart check that and
        // open the right settings page.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hipersign.sio_connect/battery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "free" -> {
                        val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "brand" -> result.success(android.os.Build.MANUFACTURER ?: "")
                    // the prayer alarm screen: over the lock screen and wake the screen, only while it is open
                    "lock" -> {
                        val on = call.argument<Boolean>("on") == true
                        if (android.os.Build.VERSION.SDK_INT >= 27) {
                            setShowWhenLocked(on)
                            setTurnScreenOn(on)
                        }
                        result.success(true)
                    }
                    "battery" -> result.success(open(listOf(
                        Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(android.net.Uri.parse("package:$packageName")))))
                    "autostart" -> result.success(open(listOf(
                        comp("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
                        comp("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
                        comp("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
                        comp("com.oplus.safecenter", "com.oplus.safecenter.startupapp.StartupAppListActivity"),
                        comp("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
                        comp("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
                        comp("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                        comp("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"),
                        Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(android.net.Uri.parse("package:$packageName")))))
                    else -> result.notImplemented()
                }
            }
    }

    private fun comp(pkg: String, cls: String) =
        Intent().setComponent(android.content.ComponentName(pkg, cls))

    /** Opens the first settings page this phone has. */
    private fun open(intents: List<Intent>): Boolean {
        for (i in intents) {
            try {
                startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: Exception) {
            }
        }
        return false
    }
}
