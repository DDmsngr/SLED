import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yandex_maps_mapkit/init.dart' as ymk_init;
import 'app.dart';
import 'core/services/mapkit_init.dart';
import 'data/datasources/isar_datasource.dart';

// Ключ передаётся через --dart-define=YANDEX_MAPKIT_API_KEY=... в CI.
const _yandexApiKey = String.fromEnvironment('YANDEX_MAPKIT_API_KEY');

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await IsarDatasource.instance.init();

  // Инициализация Yandex MapKit до runApp. В новом плагине
  // (yandex_maps_mapkit) ключ задаётся в Dart, а не в AndroidManifest.
  try {
    if (_yandexApiKey.isEmpty) {
      MapkitInit.status = 'no_key_in_dart_define';
    } else {
      await ymk_init.initMapkit(apiKey: _yandexApiKey);
      MapkitInit.status = 'ok:${_yandexApiKey.substring(0, 8)}';
    }
  } catch (e) {
    MapkitInit.status = 'err:$e';
  }

  FlutterForegroundTask.initCommunicationPort();

  FlutterNativeSplash.remove();

  runApp(const ProviderScope(child: GpsTrackerApp()));
}
