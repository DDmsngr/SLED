import 'package:hive/hive.dart';

import '../models/track_session_model.dart';
import '../models/photo_marker_model.dart';

/// Чтение/запись сессий и маркеров в Hive.
class LocalSessionDatasource {
  Box<TrackSessionModel> get _sessions =>
      Hive.box<TrackSessionModel>('sessions');
  Box<PhotoMarkerModel> get _markers => Hive.box<PhotoMarkerModel>('markers');

  Future<void> saveSession(TrackSessionModel model) async {
    await _sessions.put(model.id, model);
  }

  Future<void> deleteSession(String id) async {
    await _sessions.delete(id);
    final toDelete = _markers.values
        .where((m) => m.sessionId == id)
        .map((m) => m.key)
        .toList();
    await _markers.deleteAll(toDelete);
  }

  List<TrackSessionModel> loadAllSessions() {
    final list = _sessions.values.toList();
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  TrackSessionModel? loadSession(String id) => _sessions.get(id);

  Future<void> saveMarker(PhotoMarkerModel model) async {
    await _markers.put(model.id, model);
  }

  List<PhotoMarkerModel> markersForSession(String sessionId) =>
      _markers.values.where((m) => m.sessionId == sessionId).toList();
}
