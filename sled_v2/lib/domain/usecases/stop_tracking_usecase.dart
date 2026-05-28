import '../repositories/tracking_repository.dart';

/// Юз-кейс остановки GPS-трекинга.
class StopTrackingUseCase {
  const StopTrackingUseCase(this._repo);
  final TrackingRepository _repo;

  Future<void> call() => _repo.stopTracking();
}
