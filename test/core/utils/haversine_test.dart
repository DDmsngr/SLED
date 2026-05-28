import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sled/core/utils/haversine.dart';

void main() {
  group('haversineDistance', () {
    test('одинаковые точки — расстояние 0', () {
      const pt = LatLng(55.751244, 37.618423);
      expect(haversineDistance(pt, pt), closeTo(0.0, 0.001));
    });
    test('Москва → Санкт-Петербург ≈ 634 км', () {
      const moscow = LatLng(55.7558, 37.6176);
      const spb = LatLng(59.9343, 30.3351);
      final dist = haversineDistance(moscow, spb);
      expect(dist, greaterThan(630000));
      expect(dist, lessThan(640000));
    });
    test('msToKmh: 10 м/с → 36 км/ч', () {
      expect(msToKmh(10.0), closeTo(36.0, 0.01));
    });
  });
}
