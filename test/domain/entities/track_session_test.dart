import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sled/domain/domain.dart';

void main() {
  group('TrackSession', () {
    final start = DateTime(2025, 6, 1, 10, 0, 0);
    final end   = DateTime(2025, 6, 1, 11, 30, 0);

    final session = TrackSession(
      id: 'test-id',
      title: 'Тестовый трек',
      startedAt: start,
      finishedAt: end,
      points: const [],
      photos: const [],
      distanceMeters: 5000,
    );

    test('duration вычисляется корректно', () {
      expect(session.duration, const Duration(hours: 1, minutes: 30));
    });
    test('copyWith обновляет только нужные поля', () {
      final updated = session.copyWith(distanceMeters: 9999);
      expect(updated.id, session.id);
      expect(updated.distanceMeters, 9999);
      expect(updated.title, session.title);
    });
    test('равенство по id', () {
      final duplicate = session.copyWith(title: 'Другое название');
      expect(session, duplicate);
    });
  });

  group('TrackPoint', () {
    test('создаётся с корректными полями', () {
      final pt = TrackPoint(
        position: const LatLng(55.75, 37.62),
        timestamp: DateTime.now(),
        speedMs: 1.5,
        accuracyM: 5.0,
      );
      expect(pt.speedMs, 1.5);
      expect(pt.position.latitude, 55.75);
    });
  });
}
