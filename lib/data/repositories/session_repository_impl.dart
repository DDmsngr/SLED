import 'dart:io';

import '../../domain/entities/track_session.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/entities/photo_marker.dart';
import '../../domain/repositories/session_repository.dart';
import '../datasources/local_session_datasource.dart';
import '../models/track_session_model.dart';
import '../models/photo_marker_model.dart';

class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this._datasource);

  final LocalSessionDatasource _datasource;

  @override
  Future<void> saveSession(TrackSession session) async {
    final model = TrackSessionModel.fromEntity(session);
    await _datasource.saveSession(model);
  }

  @override
  Future<List<TrackSession>> loadSessions() async {
    final models = _datasource.loadAllSessions();
    return models.map((m) {
      final markers = _datasource
          .markersForSession(m.id)
          .map((pm) => pm.toEntity())
          .toList();
      return m.toEntity(markers);
    }).toList();
  }

  @override
  Future<TrackSession?> loadSession(String id) async {
    final m = _datasource.loadSession(id);
    if (m == null) return null;
    final markers = _datasource
        .markersForSession(id)
        .map((pm) => pm.toEntity())
        .toList();
    return m.toEntity(markers);
  }

  @override
  Future<void> deleteSession(String id) async {
    final markers = _datasource.markersForSession(id);
    for (final m in markers) {
      final file = File(m.filePath);
      if (await file.exists()) await file.delete();
    }
    await _datasource.deleteSession(id);
  }

  @override
  Future<void> addTrackPoint(String sessionId, TrackPoint point) async {
    final model = _datasource.loadSession(sessionId);
    if (model == null) return;
    model.lats.add(point.position.latitude);
    model.lngs.add(point.position.longitude);
    model.timestampsMs.add(point.timestamp.millisecondsSinceEpoch);
    model.speeds.add(point.speedMs);
    model.accuracies.add(point.accuracyM);
    await _datasource.saveSession(model);
  }

  @override
  Future<void> addPhotoMarker(String sessionId, PhotoMarker marker) async {
    final model = PhotoMarkerModel.fromEntity(marker, sessionId);
    await _datasource.saveMarker(model);
    final session = _datasource.loadSession(sessionId);
    if (session != null && !session.photoIds.contains(marker.id)) {
      session.photoIds.add(marker.id);
      await _datasource.saveSession(session);
    }
  }
}
