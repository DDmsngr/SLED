import 'package:latlong2/latlong.dart';
import '../entities/track_point.dart';

/// Контракт репозитория GPS-трекинга.
abstract interface class TrackingRepository {
  Stream<TrackPoint> get trackPointStream;
  Future<bool> requestPermission();
  Future<void> startTracking();
  Future<void> stopTracking();
  Future<LatLng?> getCurrentPosition();
}
