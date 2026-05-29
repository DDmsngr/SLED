import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/datasources/isar_datasource.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Isar: открываем одну БД для всего приложения.
  await IsarDatasource.instance.init();

  FlutterForegroundTask.initCommunicationPort();

  FlutterNativeSplash.remove();

  runApp(const ProviderScope(child: GpsTrackerApp()));
}
