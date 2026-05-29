import '../entities/photo_marker.dart';
import '../entities/track_session.dart';

/// Контракт репозитория хранения сессий.
abstract interface class SessionRepository {
  /// Живой поток — реактивно отражает изменения Isar без ручного invalidate.
  Stream<List<TrackSession>> watchSessions();

  Future<void> saveSession(TrackSession session);
  Future<List<TrackSession>> loadSessions();
  Future<TrackSession?> loadSession(String id);
  Future<void> deleteSession(String id);
  Future<void> addPhotoMarker(String sessionId, PhotoMarker marker);
}
