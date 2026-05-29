import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/utils/haversine.dart';
import '../../data/datasources/gps_datasource.dart';
import '../../data/datasources/isar_datasource.dart';
import '../../data/repositories/isar_session_repository_impl.dart';
import '../../data/repositories/tracking_repository_impl.dart';
import '../../domain/entities/activity_type.dart';
import '../../domain/entities/gps_profile.dart';
import '../../domain/entities/photo_marker.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/entities/track_session.dart';
import '../../domain/repositories/session_repository.dart';

// ── Провайдеры зависимостей ───────────────────────────────────────────────────

final gpsDatasourceProvider = Provider((_) => GpsDatasource());

final trackingRepositoryProvider = Provider(
  (ref) => TrackingRepositoryImpl(ref.watch(gpsDatasourceProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (_) => IsarSessionRepositoryImpl(IsarDatasource.instance),
);

// ── Стейт-машина ─────────────────────────────────────────────────────────────

/// Перечисление состояний трекинга.
enum TrackingStatus {
  /// Трекинг не запущен.
  idle,

  /// Foreground Service и сессия создаются (~3–5 с).
  /// UI показывает LoadingOverlay, предотвращая мигание старым экраном.
  initializing,

  /// GPS-запись активна.
  tracking,

  /// Запись приостановлена.
  paused,
}

class TrackingState {
  const TrackingState({
    this.status = TrackingStatus.idle,
    this.session,
    this.currentPosition,
    this.displayDuration = Duration.zero,
    this.errorMessage,
  });

  final TrackingStatus status;
  final TrackSession? session;
  final LatLng? currentPosition;
  final Duration displayDuration;
  final String? errorMessage;

  // ── Derived booleans (обратная совместимость с UI) ───────────────────────
  bool get isIdle          => status == TrackingStatus.idle;
  bool get isInitializing  => status == TrackingStatus.initializing;
  bool get isTracking      => status == TrackingStatus.tracking ||
                              status == TrackingStatus.paused;
  bool get isActivelyRecording => status == TrackingStatus.tracking;
  bool get isPaused        => status == TrackingStatus.paused;

  TrackingState copyWith({
    TrackingStatus? status,
    TrackSession? session,
    LatLng? currentPosition,
    Duration? displayDuration,
    String? errorMessage,
  }) =>
      TrackingState(
        status:          status          ?? this.status,
        session:         session         ?? this.session,
        currentPosition: currentPosition ?? this.currentPosition,
        displayDuration: displayDuration ?? this.displayDuration,
        errorMessage:    errorMessage,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class TrackingNotifier extends StateNotifier<TrackingState> {
  TrackingNotifier(this._ref) : super(const TrackingState());

  final Ref _ref;
  StreamSubscription<TrackPoint>? _gpsSub;
  Timer? _uiTimer;
  DateTime? _pauseStartTime;
  int _totalPausedMs = 0;

  final _uuid = const Uuid();
  final _picker = ImagePicker();

  TrackingRepositoryImpl get _trackingRepo =>
      _ref.read(trackingRepositoryProvider);
  SessionRepository get _sessionRepo =>
      _ref.read(sessionRepositoryProvider);

  // ── Запуск ───────────────────────────────────────────────────────────────

  Future<void> startTracking(
    ActivityType activityType, {
    GpsProfile profile = GpsProfile.auto,
  }) async {
    // Первый синхронный эмит: UI видит initializing немедленно,
    // не успевает показать старое состояние.
    state = state.copyWith(status: TrackingStatus.initializing);

    try {
      final hasPermission = await _trackingRepo.requestPermission();
      if (!hasPermission) {
        state = state.copyWith(
          status: TrackingStatus.idle,
          errorMessage: 'Нет разрешения на геолокацию',
        );
        return;
      }

      await _initForegroundService();

      final sessionId = _uuid.v4();
      final now = DateTime.now();
      _totalPausedMs = 0;

      final newSession = TrackSession(
        id: sessionId,
        title: _sledTitle(now),
        startedAt: now,
        points: const [],
        photos: const [],
        distanceMeters: 0,
        activityType: activityType,
      );
      await _sessionRepo.saveSession(newSession);
      await _trackingRepo.startTracking(
        profile: profile,
        activityType: activityType,
      );

      _gpsSub = _trackingRepo.trackPointStream.listen(
        (point) => _onNewPoint(sessionId, point),
        onError: (e) => state = state.copyWith(errorMessage: e.toString()),
      );

      _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (state.status == TrackingStatus.tracking &&
            state.session != null) {
          final elapsed = DateTime.now()
                  .difference(state.session!.startedAt) -
              Duration(milliseconds: _totalPausedMs);
          state = state.copyWith(displayDuration: elapsed);
        }
      });

      // Foreground Service поднят — переводим в tracking.
      state = state.copyWith(
        status: TrackingStatus.tracking,
        session: newSession,
        displayDuration: Duration.zero,
      );
    } catch (e) {
      state = state.copyWith(
        status: TrackingStatus.idle,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Пауза ────────────────────────────────────────────────────────────────

  Future<void> pauseTracking() async {
    if (state.status != TrackingStatus.tracking) return;
    _pauseStartTime = DateTime.now();
    await _gpsSub?.cancel();
    _gpsSub = null;
    state = state.copyWith(status: TrackingStatus.paused);
  }

  // ── Продолжить ───────────────────────────────────────────────────────────

  Future<void> resumeTracking() async {
    if (state.status != TrackingStatus.paused) return;
    if (_pauseStartTime != null) {
      _totalPausedMs +=
          DateTime.now().difference(_pauseStartTime!).inMilliseconds;
      _pauseStartTime = null;
    }
    final sessionId = state.session!.id;
    _gpsSub = _trackingRepo.trackPointStream.listen(
      (point) => _onNewPoint(sessionId, point),
      onError: (e) => state = state.copyWith(errorMessage: e.toString()),
    );
    state = state.copyWith(status: TrackingStatus.tracking);
  }

  // ── Остановка ────────────────────────────────────────────────────────────

  Future<void> stopTracking() async {
    _uiTimer?.cancel();
    _uiTimer = null;
    await _gpsSub?.cancel();
    _gpsSub = null;
    await _trackingRepo.stopTracking();
    await FlutterForegroundTask.stopService();

    if (state.session != null) {
      final finished = state.session!.copyWith(
        finishedAt: DateTime.now(),
        pausedDurationMs: _totalPausedMs,
      );
      await _sessionRepo.saveSession(finished);
      state = TrackingState(
        status: TrackingStatus.idle,
        session: finished,
      );
    } else {
      state = const TrackingState(status: TrackingStatus.idle);
    }
  }

  // ── Новая GPS-точка ───────────────────────────────────────────────────────

  void _onNewPoint(String sessionId, TrackPoint point) {
    if (state.status != TrackingStatus.tracking) return;
    final current = state.session;
    if (current == null) return;

    final newPoints = [...current.points, point];
    double dist = current.distanceMeters;
    if (current.points.isNotEmpty) {
      dist += haversineDistance(current.points.last.position, point.position);
    }
    final updated = current.copyWith(points: newPoints, distanceMeters: dist);
    state = state.copyWith(session: updated, currentPosition: point.position);

    // Персистируем каждые 10 точек чтобы не терять данные при крэше.
    if (newPoints.length % 10 == 0) {
      _sessionRepo.saveSession(updated);
    }
  }

  // ── Фото ─────────────────────────────────────────────────────────────────

  Future<void> takePhoto() async {
    final current = state.session;
    final pos = state.currentPosition;
    if (current == null || pos == null) return;

    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (xfile == null) return;

      final docsDir = await getApplicationDocumentsDirectory();
      final dest = p.join(docsDir.path, 'photos', '${_uuid.v4()}.jpg');
      await Directory(p.dirname(dest)).create(recursive: true);
      await File(xfile.path).copy(dest);

      final marker = PhotoMarker(
        id: _uuid.v4(),
        filePath: dest,
        position: pos,
        timestamp: DateTime.now(),
      );

      await _sessionRepo.addPhotoMarker(current.id, marker);
      state = state.copyWith(
        session: current.copyWith(photos: [...current.photos, marker]),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Ошибка камеры: $e');
    }
  }

  // ── Foreground Service ───────────────────────────────────────────────────

  Future<void> _initForegroundService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sled_channel',
        channelName: 'SLED',
        channelDescription: 'Запись следа в фоне',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
    await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: 'SLED активен',
      notificationText: 'Записываю след...',
    );
  }

  String _sledTitle(DateTime dt) {
    const months = [
      '',
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return 'След от ${dt.day} ${months[dt.month]}';
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }
}

final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>(
  (ref) => TrackingNotifier(ref),
);
