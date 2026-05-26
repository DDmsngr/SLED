import 'package:flutter_test/flutter_test.dart';
import 'package:gps_photo_tracker/domain/domain.dart';
import 'package:latlong2/latlong.dart';

/// Минимальный smoke-тест: проверяем, что TrackSession.copyWith работает
/// без реального Hive (полный интеграционный тест требует runApp).
void main() {
  group('SessionRepository smoke', () {
    test('TrackSession.copyWith сохраняет id', () {
      final s = TrackSession(
        id: 'abc',
        title: 'Test',
        startedAt: DateTime.now(),
        points: const [],
        photos: const [],
        distanceMeters: 0,
      );
      final updated = s.copyWith(distanceMeters: 100);
      expect(updated.id, 'abc');
      expect(updated.distanceMeters, 100);
    });

    test('PhotoMarker хранит координаты', () {
      final marker = PhotoMarker(
        id: 'photo-1',
        filePath: '/tmp/photo.jpg',
        position: const LatLng(59.93, 30.32),
        timestamp: DateTime.now(),
      );
      expect(marker.position.latitude, closeTo(59.93, 0.001));
    });
  });
}
