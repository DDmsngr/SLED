package com.example.sled

import android.app.Application
import android.content.pm.PackageManager
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {

    companion object {
        /** Реальный статус инициализации MapKit — читаем из MainActivity через MethodChannel. */
        @Volatile var mapKitInitStatus: String = "not_started"
    }

    override fun onCreate() {
        super.onCreate()
        try {
            val ai = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            val key = ai.metaData?.getString("com.yandex.android.sdk.MAPKIT_API_KEY") ?: ""
            when {
                key.isEmpty() -> {
                    mapKitInitStatus = "no_key_in_manifest"
                }
                key == "test_api_key" -> {
                    mapKitInitStatus = "test_key_only"
                }
                else -> {
                    MapKitFactory.setApiKey(key)
                    mapKitInitStatus = "ok:${key.take(8)}"
                }
            }
        } catch (e: Exception) {
            mapKitInitStatus = "err:${e.javaClass.simpleName}:${e.message?.take(80)}"
        }
    }
}
