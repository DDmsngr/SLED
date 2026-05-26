import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/track_session.dart';
import '../../domain/entities/photo_marker.dart';
import 'track_map_widget.dart';

/// Коллаж: карта + сетка фото + статистика.
/// Используется как превью и как источник для RepaintBoundary → PNG.
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
                  child: TrackMapWidget(session: session, interactive: false),
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
        label:
            Text(text, style: Theme.of(ctx).textTheme.labelMedium),
        padding: EdgeInsets.zero,
      );
}
