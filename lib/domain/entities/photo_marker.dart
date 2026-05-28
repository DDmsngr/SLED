import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Фото, привязанное к GPS-точке.
class PhotoMarker extends Equatable {
  const PhotoMarker({
    required this.id,
    required this.filePath,
    required this.position,
    required this.timestamp,
  });

  final String id;
  final String filePath;
  final LatLng position;
  final DateTime timestamp;

  @override
  List<Object?> get props => [id];
}
