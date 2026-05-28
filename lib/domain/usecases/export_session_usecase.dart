import '../entities/track_session.dart';
import '../repositories/session_repository.dart';

/// Юз-кейс получения полных данных сессии для экспорта.
class ExportSessionUseCase {
  const ExportSessionUseCase(this._repo);
  final SessionRepository _repo;

  Future<TrackSession?> call(String sessionId) => _repo.loadSession(sessionId);
}
