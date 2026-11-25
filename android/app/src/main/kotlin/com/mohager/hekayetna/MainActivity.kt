package com.mohager.hekayetna

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // Free space for the recording low-storage guard (spec 02).
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mohager.hekayetna/storage")
        .setMethodCallHandler { call, result ->
          if (call.method == "freeBytes") {
            try {
              result.success(StatFs(filesDir.absolutePath).availableBytes)
            } catch (e: Exception) {
              result.error("unavailable", e.message, null)
            }
          } else {
            result.notImplemented()
          }
        }
  }
}
