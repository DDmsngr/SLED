import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hive/hive.dart';

import '../../../data/models/track_session_model.dart';
import '../../../data/models/photo_marker_model.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/session_provider.dart';

/// Экран разработчика. Доступ: 5 тапов по лого на HomeScreen.
class DevScreen extends ConsumerWidget {
  const DevScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingProvider);
    final sessionsAsync = ref.watch(sessionsProvider);

    final sessionsBox = Hive.box<TrackSessionModel>('sessions');
    final markersBox = Hive.box<PhotoMarkerModel>('markers');

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠 Dev Mode'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Очистить все данные',
            onPressed: () => _confirmClear(context, ref, sessionsBox, markersBox),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Hive Stats ───────────────────────────────────────────
          _Section(
            title: 'Хранилище Hive',
            children: [
              _Row('Сессий в боксе', '${sessionsBox.length}'),
              _Row('Маркеров в боксе', '${markersBox.length}'),
              _Row('Сессий (из провайдера)',
                  sessionsAsync.when(
                    data: (s) => '${s.length}',
                    loading: () => '...',
                    error: (e, _) => 'Err: $e',
                  )),
            ],
          ),
          const Gap(16),

          // ── Tracking State ───────────────────────────────────────
          _Section(
            title: 'Состояние трекинга',
            children: [
              _Row('isTracking', '${trackingState.isTracking}'),
              _Row('isPaused', '${trackingState.isPaused}'),
              _Row('displayDuration',
                  trackingState.displayDuration.toString()),
              _Row('currentPosition',
                  trackingState.currentPosition?.toString() ?? 'null'),
              _Row('Точек в треке',
                  '${trackingState.session?.points.length ?? 0}'),
              _Row('Дистанция',
                  '${trackingState.session?.distanceMeters.toStringAsFixed(1) ?? 0} м'),
              _Row('Тип активности',
                  trackingState.session?.activityType.label ?? 'нет'),
            ],
          ),
          const Gap(16),

          // ── Sessions List ────────────────────────────────────────
          _Section(
            title: 'Все следы',
            children: sessionsAsync.when(
              data: (sessions) => sessions.isEmpty
                  ? [const _Row('Пусто', '')]
                  : sessions
                      .map((s) => _Row(
                            s.title,
                            '${s.points.length} pts · '
                            '${s.photos.length} фото · '
                            '${s.distanceMeters.toStringAsFixed(0)} м',
                          ))
                      .toList(),
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (e, _) => [Text('Ошибка: $e')],
            ),
          ),
          const Gap(16),

          // ── Last GPS Points ──────────────────────────────────────
          if (trackingState.session != null &&
              trackingState.session!.points.isNotEmpty)
            _Section(
              title: 'Последние 5 точек GPS',
              children: trackingState.session!.points.reversed
                  .take(5)
                  .map((pt) => _Row(
                        pt.timestamp.toIso8601String().substring(11, 19),
                        '${pt.position.latitude.toStringAsFixed(6)}, '
                        '${pt.position.longitude.toStringAsFixed(6)}\n'
                        'Скор: ${(pt.speedMs * 3.6).toStringAsFixed(1)} км/ч  '
                        'Точн: ${pt.accuracyM.toStringAsFixed(0)} м',
                      ))
                  .toList(),
            ),

          const Gap(32),
          OutlinedButton.icon(
            onPressed: () => _copyDebugInfo(context, trackingState, sessionsBox),
            icon: const Icon(Icons.copy),
            label: const Text('Скопировать дамп'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    Box sessionsBox,
    Box markersBox,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Удалить ВСЕ данные?'),
        content: const Text(
            'Все следы и фотографии будут удалены безвозвратно.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить всё'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await sessionsBox.clear();
      await markersBox.clear();
      ref.invalidate(sessionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Все данные удалены')),
        );
      }
    }
  }

  void _copyDebugInfo(BuildContext context, dynamic state, Box box) {
    final info = '''
=== SLED Debug Dump ===
Sessions in Hive: ${box.length}
isTracking: ${state.isTracking}
isPaused: ${state.isPaused}
Points: ${state.session?.points.length ?? 0}
Distance: ${state.session?.distanceMeters ?? 0} m
Activity: ${state.session?.activityType.label ?? 'none'}
''';
    Clipboard.setData(ClipboardData(text: info));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скопировано в буфер')),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.deepOrange)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
