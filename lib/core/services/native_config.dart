import 'package:flutter/services.dart';
import 'mapkit_init.dart';

abstract class NativeConfig {
  static const _channel = MethodChannel('sled/config');

  // После миграции на yandex_maps_mapkit: init и ключ живут в Dart,
  // поэтому эти два поля читаем напрямую из [MapkitInit], а не через канал.
  static Future<String> yandexKeyPrefix() async =>
      MapkitInit.status.startsWith('ok:')
          ? MapkitInit.status.substring(3)
          : 'in_dart_define';
  static Future<String> mapKitInitStatus() async => MapkitInit.status;

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
