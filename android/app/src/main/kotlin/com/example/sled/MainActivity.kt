package com.example.sled

import android.content.pm.PackageManager
import com.yandex.mapkit.MapKitFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var mapKitInitStatus = "app_level"

    override fun onStart() {
        super.onStart()
        try { MapKitFactory.getInstance().onStart() } catch (_: Exception) {}
    }

    override fun onStop() {
        super.onStop()
        try { MapKitFactory.getInstance().onStop() } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sled/config")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getYandexKeyPrefix" -> {
                        try {
                            val ai = packageManager.getApplicationInfo(
                                packageName, PackageManager.GET_META_DATA
                            )
                            val key = ai.metaData
                                ?.getString("com.yandex.android.sdk.MAPKIT_API_KEY")
                                ?: "null"
                            result.success(if (key.length >= 8) key.substring(0, 8) else key)
                        } catch (e: Exception) {
                            result.success("error:${e.message?.take(40)}")
                        }
                    }
                    "getMapKitInitStatus" -> result.success(mapKitInitStatus)
                    else -> result.notImplemented()
                }
            }
    }
}
