import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/photo_marker.dart';

part 'photo_marker_model.g.dart';

@HiveType(typeId: 1)
class PhotoMarkerModel extends HiveObject {
  @HiveField(0) String id = '';
  @HiveField(1) String sessionId = '';
  @HiveField(2) String filePath = '';
  @HiveField(3) double lat = 0;
  @HiveField(4) double lng = 0;
  @HiveField(5) DateTime timestamp = DateTime.now();

  static PhotoMarkerModel fromEntity(PhotoMarker e, String sessionId) =>
      PhotoMarkerModel()
        ..id = e.id
        ..sessionId = sessionId
        ..filePath = e.filePath
        ..lat = e.position.latitude
        ..lng = e.position.longitude
        ..timestamp = e.timestamp;

  PhotoMarker toEntity() => PhotoMarker(
        id: id,
        filePath: filePath,
        position: LatLng(lat, lng),
        timestamp: timestamp,
      );
}
