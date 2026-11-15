package com.hipersign.sio_connect

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is needed for the fingerprint prompt (local_auth)
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
