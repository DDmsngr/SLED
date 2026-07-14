import 'package:flutter/services.dart';

abstract class NativeConfig {
  static const _channel = MethodChannel('sled/config');

  static Future<String> yandexKeyPrefix() => _call('getYandexKeyPrefix');
  static Future<String> mapKitInitStatus() => _call('getMapKitInitStatus');
  static Future<String> appSha1() => _call('getAppSha1');
  static Future<String> appPackage() => _call('getAppPackage');
  static Future<String> mapKitVersion() => _call('getMapKitVersion');

  static Future<String> _call(String method) async {
    try {
      final v = await _channel.invokeMethod<String>(method);
      return v ?? 'null';
    } on MissingPluginException {
      return 'no-channel';
    } catch (e) {
      return 'err:$e';
    }
  }
}
