import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Одна точка GPS-трека.
class TrackPoint extends Equatable {
  const TrackPoint({
    required this.position,
    required this.timestamp,
    required this.speedMs,
    required this.accuracyM,
    this.altitudeM = 0.0,
  });

  final LatLng position;
  final DateTime timestamp;
  final double speedMs;
  final double accuracyM;
  final double altitudeM;

  @override
  List<Object?> get props => [position, timestamp];
}
