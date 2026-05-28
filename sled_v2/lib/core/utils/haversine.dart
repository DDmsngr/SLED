import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Расстояние между двумя точками по формуле Haversine (метры).
double haversineDistance(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final sinDLat = sin(dLat / 2);
  final sinDLon = sin(dLon / 2);
  final h = sinDLat * sinDLat +
      cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * sinDLon * sinDLon;
  return 2 * r * asin(sqrt(h));
}

double _rad(double deg) => deg * pi / 180;

/// Метры/сек → км/ч.
double msToKmh(double ms) => ms * 3.6;
