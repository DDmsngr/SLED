import '../repositories/tracking_repository.dart';

/// Юз-кейс запуска GPS-трекинга.
class StartTrackingUseCase {
  const StartTrackingUseCase(this._repo);
  final TrackingRepository _repo;

  Future<bool> call() async {
    final ok = await _repo.requestPermission();
    if (!ok) return false;
    await _repo.startTracking();
    return true;
  }
}
