import 'package:flutter/services.dart';

abstract class NativeConfig {
  static const _channel = MethodChannel('sled/config');

  static Future<String> yandexKeyPrefix() async {
    try {
      final v = await _channel.invokeMethod<String>('getYandexKeyPrefix');
      return v ?? 'null';
    } on MissingPluginException {
      return 'no-channel';
    } catch (e) {
      return 'err';
    }
  }

  static Future<String> mapKitInitStatus() async {
    try {
      final v = await _channel.invokeMethod<String>('getMapKitInitStatus');
      return v ?? 'null';
    } on MissingPluginException {
      return 'no-channel';
    } catch (e) {
      return 'err';
    }
  }
}
