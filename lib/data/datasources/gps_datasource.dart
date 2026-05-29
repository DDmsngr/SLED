// hide ActivityType: geolocator_apple экспортирует своё ActivityType,
// которое конфликтует с нашим domain-entity.
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/utils/haversine.dart';
import '../../domain/entities/activity_type.dart';
import '../../domain/entities/gps_profile.dart';
import '../../domain/entities/track_point.dart';

/// GPS-источник данных с профилями, Fused Location Provider и
/// физическим фильтром для борьбы с GPS-спуфингом/глушением.
class GpsDatasource {
  GpsProfile _profile = GpsProfile.auto;
  ActivityType _activityType = ActivityType.other;

  TrackPoint? _lastEmittedPoint;
  Position? _lastAcceptedRaw; // для вычисления реальной скорости между точками

  final List<Position> _smoothBuf = [];

  void setProfile(GpsProfile profile, {ActivityType activityType = ActivityType.other}) {
    _profile = profile;
    _activityType = activityType;
    _smoothBuf.clear();
    _lastEmittedPoint = null;
    _lastAcceptedRaw = null;
  }

  /// Строим AndroidSettings с Fused Location Provider (forceLocationManager: false).
  /// Android автоматически смешивает GPS + сеть + Wi-Fi через FLP.
  LocationSettings _buildSettings() => AndroidSettings(
        accuracy: _profile.accuracy,
        distanceFilter: _profile.distanceFilterM.toInt(),
        forceLocationManager: false, // FLP включён: GPS + network + wifi fusion
        intervalDuration: _profile.interval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'GPS-трекинг активен',
          notificationTitle: 'GPS Трекер',
          enableWakeLock: true,
          notificationIcon: AndroidResource(
            name: 'ic_notification',
            defType: 'drawable',
          ),
        ),
      );

  Stream<TrackPoint> get positionStream {
    return Geolocator.getPositionStream(locationSettings: _buildSettings())
        .where(_preFilter)
        .map(_smooth)
        .where(_postFilter)
        .map(_toTrackPoint);
  }

  /// Первичный фильтр: точность + физический закон скорости.
  ///
  /// Спуфинг часто имеет хорошую accuracy (5–10 м), поэтому проверка
  /// accuracy недостаточна. Ключевой признак — вычисленная скорость
  /// (расстояние / Δt) превышает предел для выбранного типа активности.
  bool _preFilter(Position p) {
    // Точки с плохой точностью GPS отбрасываем
    if (p.accuracy > 50) return false;

    final prev = _lastAcceptedRaw;
    if (prev != null) {
      final dt = p.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
      // Проверяем только если между точками ≤ 30 с (при большем промежутке
      // пользователь мог резко сдвинуться, паузы/долгое ожидание сигнала).
      if (dt > 0 && dt <= 30) {
        final dist = haversineDistance(
          LatLng(prev.latitude, prev.longitude),
          LatLng(p.latitude, p.longitude),
        );
        final impliedKmh = (dist / dt) * 3.6;
        if (impliedKmh > _activityType.maxSpeedKmh) return false;
      }
    }

    _lastAcceptedRaw = p;
    return true;
  }

  /// Скользящее среднее из 3 точек — убирает GPS-джиттер.
  Position _smooth(Position p) {
    _smoothBuf.add(p);
    if (_smoothBuf.length > 3) _smoothBuf.removeAt(0);
    if (_smoothBuf.length < 3) return p;

    final avgLat = _smoothBuf.map((x) => x.latitude).reduce((a, b) => a + b) / 3;
    final avgLng = _smoothBuf.map((x) => x.longitude).reduce((a, b) => a + b) / 3;
    final avgAlt = _smoothBuf.map((x) => x.altitude).reduce((a, b) => a + b) / 3;

    return Position(
      latitude: avgLat,
      longitude: avgLng,
      altitude: avgAlt,
      timestamp: p.timestamp,
      accuracy: p.accuracy,
      altitudeAccuracy: p.altitudeAccuracy,
      headingAccuracy: p.headingAccuracy,
      heading: p.heading,
      speed: p.speed,
      speedAccuracy: p.speedAccuracy,
    );
  }

  /// Вторичный фильтр: не принимаем точку ближе minPointDistanceMeters
  /// от последней принятой — режет дублирование на стоянке.
  bool _postFilter(Position p) {
    if (_lastEmittedPoint == null) return true;
    final dist = haversineDistance(
      _lastEmittedPoint!.position,
      LatLng(p.latitude, p.longitude),
    );
    return dist >= AppConstants.minPointDistanceMeters;
  }

  TrackPoint _toTrackPoint(Position p) {
    final point = TrackPoint(
      position: LatLng(p.latitude, p.longitude),
      timestamp: p.timestamp,
      speedMs: p.speed,
      accuracyM: p.accuracy,
      altitudeM: p.altitude,
    );
    _lastEmittedPoint = point;
    return point;
  }

  void reset() {
    _lastEmittedPoint = null;
    _lastAcceptedRaw = null;
    _smoothBuf.clear();
  }

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw const LocationError('GPS отключён в системе');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationError('Разрешение отклонено навсегда');
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<LatLng?> getCurrentPosition() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}
