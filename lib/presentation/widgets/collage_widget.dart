import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
// Импортируем только LatLng: latlong2 экспортирует свой Path (полилиния
// для навигации), который затеняет dart:ui.Path и ломает CustomPainter.
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/track_session.dart';
import '../../domain/entities/photo_marker.dart';
import '../../domain/entities/track_point.dart';

/// Коллаж-«паспорт следа»: минималистичный маршрут + сетка фото + статы.
///
/// Раньше сюда встраивался живой TrackMapWidget (Yandex PlatformView),
/// но RepaintBoundary.toImage() не захватывает PlatformView — на PNG
/// оставалась только рамка без карты. Теперь маршрут рисуется через
/// CustomPainter из точек трека — работает 100% в snapshot.
class CollageWidget extends StatelessWidget {
  const CollageWidget({
    super.key,
    required this.session,
    this.size = const Size(1080, 1920),
  });

  final TrackSession session;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = session.photos;
    final hasTrack = session.points.length >= 2;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            _Header(session: session),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: hasTrack
                        ? CustomPaint(
                            painter: _TrackPathPainter(
                              points: session.points,
                              color: theme.colorScheme.primary,
                            ),
                            child: const SizedBox.expand(),
                          )
                        : const Center(
                            child: Icon(Icons.route,
                                size: 64, color: Colors.grey),
                          ),
                  ),
                ),
              ),
            ),
            const Gap(8),
            if (photos.isNotEmpty)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _PhotoGrid(photos: photos.take(9).toList()),
                ),
              ),
            const Gap(8),
            _StatsRow(session: session),
            const Gap(12),
          ],
        ),
      ),
    );
  }
}

/// Рисует полилинию трека, вписанную в bounding box контейнера.
/// Использует линейную проекцию lat/lon (для локальных треков достаточно
/// точно, для трансконтинентальных — исказится, но для показа маршрута норм).
class _TrackPathPainter extends CustomPainter {
  _TrackPathPainter({required this.points, required this.color});
  final List<TrackPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final tp in points) {
      final p = tp.position;
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // Небольшой отступ вокруг маршрута
    const padding = 24.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    // Сохраняем aspect ratio: делим по большему измерению
    final latRange = math.max(maxLat - minLat, 1e-6);
    final lngRange = math.max(maxLng - minLng, 1e-6);
    final scale = math.min(w / lngRange, h / latRange);

    final offsetX = padding + (w - lngRange * scale) / 2;
    final offsetY = padding + (h - latRange * scale) / 2;

    Offset toXY(LatLng ll) => Offset(
          offsetX + (ll.longitude - minLng) * scale,
          offsetY + (maxLat - ll.latitude) * scale, // Y инвертирован
        );

    final path = Path()..moveTo(toXY(points.first.position).dx,
        toXY(points.first.position).dy);
    for (int i = 1; i < points.length; i++) {
      final o = toXY(points[i].position);
      path.lineTo(o.dx, o.dy);
    }

    // Обводка (outline)
    final outline = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, outline);

    // Основная линия
    final line = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);

    // Старт / финиш
    final start = toXY(points.first.position);
    final finish = toXY(points.last.position);
    canvas.drawCircle(start, 10,
        Paint()..color = Colors.green.shade600);
    canvas.drawCircle(start, 10,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke);
    canvas.drawCircle(finish, 10, Paint()..color = Colors.red.shade600);
    canvas.drawCircle(finish, 10,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _TrackPathPainter old) =>
      old.points.length != points.length || old.color != color;
}

class _Header extends StatelessWidget {
  const _Header({required this.session});
  final TrackSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.route, size: 28),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis),
                Text(formatDateTime(session.startedAt),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos});
  final List<PhotoMarker> photos;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(File(photos[i].filePath), fit: BoxFit.cover),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.session});
  final TrackSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _chip(context, Icons.route, formatDistance(session.distanceMeters)),
          _chip(context, Icons.timer, formatDuration(session.duration)),
          _chip(context, Icons.photo, '${session.photos.length} фото'),
        ],
      ),
    );
  }

  Widget _chip(BuildContext ctx, IconData icon, String text) => Chip(
        avatar: Icon(icon, size: 16),
        label: Text(text, style: Theme.of(ctx).textTheme.labelMedium),
        padding: EdgeInsets.zero,
      );
}
