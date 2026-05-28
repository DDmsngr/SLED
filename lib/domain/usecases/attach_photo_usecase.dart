import '../entities/photo_marker.dart';
import '../repositories/session_repository.dart';

/// Юз-кейс прикрепления фото к сессии.
class AttachPhotoUseCase {
  const AttachPhotoUseCase(this._repo);
  final SessionRepository _repo;

  Future<void> call(String sessionId, PhotoMarker marker) =>
      _repo.addPhotoMarker(sessionId, marker);
}
