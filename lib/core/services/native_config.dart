import 'package:flutter/services.dart';

abstract class NativeConfig {
  static const _channel = MethodChannel('sled/config');

  /// Returns first 8 chars of the Yandex API key as it appears in the
  /// compiled AndroidManifest (i.e. what the SDK actually uses).
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
}
