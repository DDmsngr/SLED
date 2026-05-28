import 'dart:io';
import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../../domain/entities/track_session.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/entities/activity_type.dart';

/// Парсит GPX-файл и возвращает [TrackSession].
/// Поддерживает стандарт GPX 1.1: trkpt, rtept, wpt.
class GpxImportService {
  const GpxImportService();

  static const _uuid = Uuid();

  Future<TrackSession?> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      return _parse(content);
    } catch (_) {
      return null;
    }
  }

  TrackSession? _parse(String xmlContent) {
    final doc = XmlDocument.parse(xmlContent);

    final nameEl = doc.findAllElements('name').firstOrNull;
    final trackName = nameEl?.innerText.trim() ?? '';

    final pointEls = [
      ...doc.findAllElements('trkpt'),
      ...doc.findAllElements('rtept'),
    ];
    if (pointEls.isEmpty) return null;

    final points = <TrackPoint>[];
    DateTime? firstTime;

    for (final el in pointEls) {
      final lat = double.tryParse(el.getAttribute('lat') ?? '');
      final lon = double.tryParse(el.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;

      DateTime ts;
      try {
        final raw = el.findElements('time').firstOrNull?.innerText.trim();
        ts = raw != null ? DateTime.parse(raw).toLocal() : DateTime.now();
      } catch (_) {
        ts = DateTime.now();
      }
      firstTime ??= ts;

      final speedRaw =
          el.findElements('speed').firstOrNull?.innerText.trim();
      final speed = double.tryParse(speedRaw ?? '') ?? 0.0;

      points.add(TrackPoint(
        position: LatLng(lat, lon),
        timestamp: ts,
        speedMs: speed,
        accuracyM: 10.0,
      ));
    }

    if (points.isEmpty) return null;

    double dist = 0;
    for (int i = 1; i < points.length; i++) {
      dist += _haversine(points[i - 1].position, points[i].position);
    }

    final now = firstTime ?? DateTime.now();
    final title = trackName.isNotEmpty ? trackName : _sledTitle(now);

    return TrackSession(
      id: _uuid.v4(),
      title: title,
      startedAt: now,
      finishedAt: points.last.timestamp,
      points: points,
      photos: const [],
      distanceMeters: dist,
      activityType: ActivityType.walk,
    );
  }

  static double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.latitude)) *
            cos(_rad(b.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return 2 * r * asin(sqrt(h));
  }

  static double _rad(double d) => d * pi / 180;

  static String _sledTitle(DateTime dt) {
    const months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return 'Импорт от ${dt.day} ${months[dt.month]}';
  }
}
