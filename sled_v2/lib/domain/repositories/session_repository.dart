import '../entities/track_session.dart';
import '../entities/track_point.dart';
import '../entities/photo_marker.dart';

/// Контракт репозитория хранения сессий.
abstract interface class SessionRepository {
  Future<void> saveSession(TrackSession session);
  Future<List<TrackSession>> loadSessions();
  Future<TrackSession?> loadSession(String id);
  Future<void> deleteSession(String id);
  Future<void> addTrackPoint(String sessionId, TrackPoint point);
  Future<void> addPhotoMarker(String sessionId, PhotoMarker marker);
}
