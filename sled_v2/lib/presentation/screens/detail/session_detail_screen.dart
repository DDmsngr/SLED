import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formatter.dart';
import '../../providers/session_provider.dart';
import '../../widgets/track_map_widget.dart';
import '../../widgets/stats_bar_widget.dart';
import '../../../domain/entities/photo_marker.dart';

/// Детальный просмотр завершённой сессии.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionByIdProvider(sessionId));

    return Scaffold(
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (session) {
          if (session == null) {
            return const Center(child: Text('Сессия не найдена'));
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(session.title),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.ios_share),
                    onPressed: () =>
                        context.push('/export/$sessionId'),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: TrackMapWidget(
                      session: session, interactive: true),
                ),
              ),
              SliverToBoxAdapter(
                  child: StatsBarWidget(session: session)),
              if (session.photos.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Фотографии',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium),
                  ),
                ),
                SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) =>
                        _PhotoTile(photo: session.photos[i]),
                    childCount: session.photos.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                ),
              ],
              const SliverPadding(
                  padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo});
  final PhotoMarker photo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullscreen(context),
      child: Image.file(
        File(photo.filePath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Colors.grey,
          child: Icon(Icons.broken_image, color: Colors.white),
        ),
      ),
    );
  }

  void _showFullscreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(photo.filePath)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(formatDateTime(photo.timestamp)),
            ),
          ],
        ),
      ),
    );
  }
}
