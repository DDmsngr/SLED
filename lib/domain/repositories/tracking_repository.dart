import 'package:latlong2/latlong.dart';
import '../entities/activity_type.dart';
import '../entities/gps_profile.dart';
import '../entities/track_point.dart';

/// Контракт репозитория GPS-трекинга.
abstract interface class TrackingRepository {
  Stream<TrackPoint> get trackPointStream;
  Future<bool> requestPermission();
  Future<void> startTracking({
    GpsProfile profile = GpsProfile.auto,
    ActivityType activityType = ActivityType.other,
  });
  Future<void> stopTracking();
  Future<LatLng?> getCurrentPosition();
}
