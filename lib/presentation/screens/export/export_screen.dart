import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/utils/date_formatter.dart';
import '../../providers/export_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/collage_widget.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  final _collageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionByIdProvider(widget.sessionId));
    final exportState = ref.watch(exportProvider);
    final exportNotifier = ref.read(exportProvider.notifier);

    ref.listen(exportProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(next.error!),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
        exportNotifier.clearError();
      }
      if (!next.isExporting && next.lastSavedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Сохранено в галерею')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Экспорт следа')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (session) {
          if (session == null) {
            return const Center(child: Text('След не найден'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Превью',
                    style: Theme.of(context).textTheme.titleMedium),
                const Gap(8),
                AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: RepaintBoundary(
                      key: _collageKey,
                      child: CollageWidget(session: session),
                    ),
                  ),
                ),
                const Gap(16),

                if (exportState.isExporting) ...[
                  LinearProgressIndicator(value: exportState.progress),
                  const Gap(8),
                  Center(
                    child: Text(
                        'Экспорт: ${(exportState.progress * 100).toInt()}%'),
                  ),
                  const Gap(16),
                ],

                FilledButton.icon(
                  onPressed: exportState.isExporting
                      ? null
                      : () => exportNotifier.exportCollage(
                            _collageKey, session),
                  icon: const Icon(Icons.image),
                  label: const Text('Сохранить след (PNG)'),
                ),
                const Gap(8),
                FilledButton.icon(
                  onPressed: exportState.isExporting
                      ? null
                      : () => exportNotifier.shareRoute(session),
                  icon: const Icon(Icons.share),
                  label: const Text('Поделиться маршрутом'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const Gap(8),
                OutlinedButton.icon(
                  onPressed: () => _showVideoComingSoon(context),
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Видео-след — скоро'),
                ),
                const Gap(16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(session.activityType.emoji,
                              style: const TextStyle(fontSize: 20)),
                          const Gap(8),
                          Expanded(
                            child: Text(session.title,
                                style:
                                    Theme.of(context).textTheme.titleSmall),
                          ),
                        ]),
                        const Gap(4),
                        Text('Дата: ${formatDateTime(session.startedAt)}'),
                        Text('Дистанция: ${formatDistance(session.distanceMeters)}'),
                        Text('Время: ${formatDuration(session.duration)}'),
                        Text('Фото: ${session.photos.length} шт.'),
                        Text('Точек GPS: ${session.points.length}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showVideoComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Видео-след'),
        content: const Text(
          'Экспорт видео появится в следующем обновлении.\n\n'
          'Пока сохраните PNG-коллаж или поделитесь маршрутом.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}
