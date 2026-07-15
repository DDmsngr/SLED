package com.example.sled

import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel остался для Dev Mode. Ключ MapKit и init теперь
        // управляются из Dart (см. lib/main.dart и MapkitInit.status),
        // поэтому большинство методов возвращают заглушки.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sled/config")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getYandexKeyPrefix"   -> result.success("in_dart_define")
                    "getMapKitInitStatus"  -> result.success("moved_to_dart")
                    "getMapKitVersion"     -> result.success("4.41.0-official")
                    "getAppSha1"           -> result.success(appSha1())
                    "getAppPackage"        -> result.success(packageName)
                    else                   -> result.notImplemented()
                }
            }
    }

    /** SHA-1 подписи APK — для регистрации в кабинете Yandex/Google. */
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
