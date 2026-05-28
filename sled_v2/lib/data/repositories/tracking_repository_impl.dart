import 'package:latlong2/latlong.dart';

import '../../domain/entities/track_point.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../datasources/gps_datasource.dart';

/// Реализация TrackingRepository поверх GpsDatasource.
class TrackingRepositoryImpl implements TrackingRepository {
  TrackingRepositoryImpl(this._datasource);

  final GpsDatasource _datasource;
  bool _active = false;

  @override
  Stream<TrackPoint> get trackPointStream => _datasource.positionStream;

  @override
  Future<bool> requestPermission() => _datasource.requestPermission();

  @override
  Future<void> startTracking() async {
    if (_active) return;
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
