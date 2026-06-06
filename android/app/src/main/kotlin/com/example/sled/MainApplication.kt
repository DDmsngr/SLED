package com.example.sled

import android.app.Application
import android.content.pm.PackageManager
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            val ai = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            val key = ai.metaData?.getString("com.yandex.android.sdk.MAPKIT_API_KEY") ?: ""
            if (key.isNotEmpty()) {
                MapKitFactory.setApiKey(key)
            }
        } catch (_: Exception) {}
    }
}
