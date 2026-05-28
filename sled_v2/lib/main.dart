import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';
import 'data/models/track_session_model.dart';
import 'data/models/photo_marker_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(TrackSessionModelAdapter());
  Hive.registerAdapter(PhotoMarkerModelAdapter());
  await Hive.openBox<TrackSessionModel>('sessions');
  await Hive.openBox<PhotoMarkerModel>('markers');

  FlutterForegroundTask.initCommunicationPort();

  runApp(
    const ProviderScope(
      child: GpsTrackerApp(),
    ),
  );
}
