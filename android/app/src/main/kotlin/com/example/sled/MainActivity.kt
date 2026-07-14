package com.example.sled

import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import com.yandex.mapkit.MapKitFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

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

                    "getMapKitInitStatus" -> result.success(MainApplication.mapKitInitStatus)

                    "getAppSha1" -> result.success(appSha1())

                    "getAppPackage" -> result.success(packageName)

                    "getMapKitVersion" -> {
                        result.success(runCatching {
                            com.yandex.runtime.Runtime.getNativeVersion()
                        }.getOrElse { "unknown" })
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /** SHA-1 подписи APK — сравниваем с тем, что зарегистрирован в кабинете Yandex. */
    private fun appSha1(): String = try {
        val signatures: Array<Signature> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = packageManager.getPackageInfo(
                packageName, PackageManager.GET_SIGNING_CERTIFICATES
            )
            info.signingInfo?.let {
                if (it.hasMultipleSigners()) it.apkContentsSigners else it.signingCertificateHistory
            } ?: emptyArray()
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
                ?: emptyArray()
        }

        if (signatures.isEmpty()) "no_signature"
        else {
            val md = MessageDigest.getInstance("SHA-1")
            md.update(signatures[0].toByteArray())
            md.digest().joinToString(":") { "%02X".format(it) }
        }
    } catch (e: Exception) {
        "err:${e.javaClass.simpleName}"
    }
}
