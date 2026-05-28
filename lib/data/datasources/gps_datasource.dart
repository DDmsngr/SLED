import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/utils/haversine.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/entities/gps_profile.dart';

/// Источник данных GPS с поддержкой профилей и улучшенной фильтрацией.
class GpsDatasource {
  GpsProfile _profile = GpsProfile.auto;
  TrackPoint? _lastEmittedPoint;

  // Буфер из 3 последних сырых позиций для скользящего среднего.
  final List<Position> _smoothBuf = [];

  void setProfile(GpsProfile profile) {
    _profile = profile;
    _smoothBuf.clear();
    _lastEmittedPoint = null;
  }

  LocationSettings _buildSettings() => AndroidSettings(
        accuracy: _profile.accuracy,
        distanceFilter: _profile.distanceFilterM.toInt(),
        forceLocationManager: false,
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

  // Первичный фильтр: откидываем явно плохие точки.
  bool _preFilter(Position p) {
    if (p.accuracy > 30) return false;
    if (msToKmh(p.speed) > AppConstants.maxSpeedKmh) return false;
    return true;
  }

  // Скользящее среднее из 3 точек для сглаживания джиттера.
  Position _smooth(Position p) {
    _smoothBuf.add(p);
    if (_smoothBuf.length > 3) _smoothBuf.removeAt(0);
    if (_smoothBuf.length < 3) return p;

    final avgLat =
        _smoothBuf.map((x) => x.latitude).reduce((a, b) => a + b) / 3;
    final avgLng =
        _smoothBuf.map((x) => x.longitude).reduce((a, b) => a + b) / 3;
    final avgAlt =
        _smoothBuf.map((x) => x.altitude).reduce((a, b) => a + b) / 3;

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

  // Вторичный фильтр: минимальная дистанция от последней принятой точки.
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
