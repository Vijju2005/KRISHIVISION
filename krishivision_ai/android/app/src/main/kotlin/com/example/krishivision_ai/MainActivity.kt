package com.example.krishivision_ai

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.krishivision_ai/maps_api"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getMapsApiKey") {
                try {
                    val ai = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    val bundle = ai.metaData
                    val apiKey = bundle?.getString("com.google.android.geo.API_KEY") ?: ""
                    result.success(apiKey)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to load API Key", e.message)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
