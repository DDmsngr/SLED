import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/track_session.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/entities/photo_marker.dart';
import '../../domain/entities/activity_type.dart';

part 'track_session_model.g.dart';

@HiveType(typeId: 0)
class TrackSessionModel extends HiveObject {
  @HiveField(0)  String id = '';
  @HiveField(1)  String title = '';
  @HiveField(2)  DateTime startedAt = DateTime.now();
  @HiveField(3)  DateTime? finishedAt;
  @HiveField(4)  List<double> lats = [];
  @HiveField(5)  List<double> lngs = [];
  @HiveField(6)  List<int> timestampsMs = [];
  @HiveField(7)  List<double> speeds = [];
  @HiveField(8)  List<double> accuracies = [];
  @HiveField(9)  List<String> photoIds = [];
  @HiveField(10) double distanceMeters = 0;
  @HiveField(11) int activityTypeIndex = 0;   // ActivityType.index
  @HiveField(12) int pausedDurationMs = 0;
  @HiveField(13) bool isSharedRoute = false;
  @HiveField(14) String routeDescription = '';

  static TrackSessionModel fromEntity(TrackSession e) {
    final m = TrackSessionModel()
      ..id = e.id
      ..title = e.title
      ..startedAt = e.startedAt
      ..finishedAt = e.finishedAt
      ..distanceMeters = e.distanceMeters
      ..activityTypeIndex = e.activityType.index
      ..pausedDurationMs = e.pausedDurationMs
      ..isSharedRoute = e.isSharedRoute
      ..routeDescription = e.routeDescription
      ..photoIds = e.photos.map((p) => p.id).toList();
    for (final pt in e.points) {
      m.lats.add(pt.position.latitude);
      m.lngs.add(pt.position.longitude);
      m.timestampsMs.add(pt.timestamp.millisecondsSinceEpoch);
      m.speeds.add(pt.speedMs);
      m.accuracies.add(pt.accuracyM);
    }
    return m;
  }

  TrackSession toEntity(List<PhotoMarker> photos) {
    final points = List.generate(lats.length, (i) {
      return TrackPoint(
        position: LatLng(lats[i], lngs[i]),
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestampsMs[i]),
        speedMs: speeds[i],
        accuracyM: accuracies[i],
      );
    });
    final type = ActivityType.values.length > activityTypeIndex
        ? ActivityType.values[activityTypeIndex]
        : ActivityType.walk;
    return TrackSession(
      id: id,
      title: title,
      startedAt: startedAt,
      finishedAt: finishedAt,
      points: points,
      photos: photos,
      distanceMeters: distanceMeters,
      activityType: type,
      pausedDurationMs: pausedDurationMs,
      isSharedRoute: isSharedRoute,
      routeDescription: routeDescription,
    );
  }
}
