import 'package:latlong2/latlong.dart';

import '../../domain/entities/activity_type.dart';
import '../../domain/entities/gps_profile.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../datasources/gps_datasource.dart';

class TrackingRepositoryImpl implements TrackingRepository {
  TrackingRepositoryImpl(this._datasource);

  final GpsDatasource _datasource;
  bool _active = false;

  @override
  Stream<TrackPoint> get trackPointStream => _datasource.positionStream;

  @override
  Future<bool> requestPermission() => _datasource.requestPermission();

  @override
  Future<void> startTracking({
    GpsProfile profile = GpsProfile.auto,
    ActivityType activityType = ActivityType.other,
  }) async {
    if (_active) return;
    _datasource.setProfile(profile, activityType: activityType);
    _datasource.reset();
    _active = true;
  }

  @override
  Future<void> stopTracking() async {
    _active = false;
  }

  @override
  Future<LatLng?> getCurrentPosition() => _datasource.getCurrentPosition();
}
