package com.example.sled

import android.content.pm.PackageManager
import com.yandex.mapkit.MapKitFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var mapKitInitStatus = "not_attempted"

    override fun onStart() {
        super.onStart()
        try { MapKitFactory.getInstance().onStart() } catch (_: Exception) {}
    }

    override fun onStop() {
        super.onStop()
        try { MapKitFactory.getInstance().onStop() } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Must initialize MapKit before registering Flutter plugins
        initMapKit()
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

    private fun initMapKit() {
        try {
            val ai = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            val key = ai.metaData?.getString("com.yandex.android.sdk.MAPKIT_API_KEY") ?: ""
            if (key.isNotEmpty()) {
                MapKitFactory.setApiKey(key)
                MapKitFactory.initialize(applicationContext)
                val prefix = if (key.length >= 8) key.substring(0, 8) else key
                mapKitInitStatus = "ok:$prefix"
            } else {
                mapKitInitStatus = "error:empty_key"
            }
        } catch (e: AssertionError) {
            // Already initialized — this is fine
            mapKitInitStatus = "already_init"
        } catch (e: Exception) {
            mapKitInitStatus = "error:${e.message?.take(50)}"
        }
    }
}
