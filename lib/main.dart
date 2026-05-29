import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'data/datasources/isar_datasource.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await IsarDatasource.instance.init();

  await YandexMapKit.instance.initMapkit(
    apiKey: AppConstants.yandexApiKey,
  );

  FlutterForegroundTask.initCommunicationPort();

  FlutterNativeSplash.remove();

  runApp(const ProviderScope(child: GpsTrackerApp()));
}
