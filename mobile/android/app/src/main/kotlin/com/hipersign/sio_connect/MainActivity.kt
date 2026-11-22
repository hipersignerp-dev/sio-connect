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
    }
}
