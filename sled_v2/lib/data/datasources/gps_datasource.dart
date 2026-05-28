import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_error.dart';
import '../../core/utils/haversine.dart';
import '../../domain/entities/track_point.dart';

/// Источник данных GPS: обёртка над geolocator с фильтрацией шума.
class GpsDatasource {
  static final LocationSettings _settings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: AppConstants.gpsDistanceFilterMeters.toInt(),
    forceLocationManager: false,
    intervalDuration: const Duration(seconds: 1),
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

  TrackPoint? _lastPoint;

  Stream<TrackPoint> get positionStream {
    return Geolocator.getPositionStream(locationSettings: _settings)
        .where(_isValidPosition)
        .map(_toTrackPoint);
  }

  bool _isValidPosition(Position p) {
    if (p.accuracy > 50) return false;
    if (msToKmh(p.speed) > AppConstants.maxSpeedKmh) return false;
    if (_lastPoint == null) return true;
    final dist = haversineDistance(
      _lastPoint!.position,
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
    );
    _lastPoint = point;
    return point;
  }

  void reset() => _lastPoint = null;

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
