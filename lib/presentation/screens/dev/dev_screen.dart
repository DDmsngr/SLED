import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../data/models/track_session_model.dart';
import '../../../data/models/photo_marker_model.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/session_provider.dart';

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
        title: const Text('Dev Mode'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Очистить все данные',
            onPressed: () =>
                _confirmClear(context, ref, sessionsBox, markersBox),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(title: 'Хранилище Hive', children: [
            _Row('Сессий в боксе', '${sessionsBox.length}'),
            _Row('Маркеров в боксе', '${markersBox.length}'),
            _Row('Сессий (провайдер)',
                sessionsAsync.when(
                  data: (s) => '${s.length}',
                  loading: () => '...',
                  error: (e, _) => 'Err',
                )),
          ]),
          const Gap(16),
          _Section(title: 'Состояние трекинга', children: [
            _Row('isTracking', '${trackingState.isTracking}'),
            _Row('isPaused', '${trackingState.isPaused}'),
            _Row('displayDuration', trackingState.displayDuration.toString()),
            _Row('currentPosition',
                trackingState.currentPosition?.toString() ?? 'null'),
            _Row('Точек', '${trackingState.session?.points.length ?? 0}'),
            _Row('Дистанция',
                '${trackingState.session?.distanceMeters.toStringAsFixed(1) ?? 0} м'),
            _Row('Активность',
                trackingState.session?.activityType.label ?? 'нет'),
          ]),
          const Gap(16),
          _Section(
            title: 'Все следы',
            children: sessionsAsync.when(
              data: (sessions) => sessions.isEmpty
                  ? [const _Row('Пусто', '')]
                  : sessions
                      .map((s) => _Row(s.title,
                          '${s.points.length} pts · ${s.photos.length} фото'))
                      .toList(),
              loading: () =>
                  [const Center(child: CircularProgressIndicator())],
              error: (e, _) => [Text('$e')],
            ),
          ),
          const Gap(16),
          if (trackingState.session != null &&
              trackingState.session!.points.isNotEmpty)
            _Section(
              title: 'Последние 5 точек GPS',
              children: trackingState.session!.points.reversed
                  .take(5)
                  .map((pt) => _Row(
                        pt.timestamp.toIso8601String().substring(11, 19),
                        '${pt.position.latitude.toStringAsFixed(5)}, '
                        '${pt.position.longitude.toStringAsFixed(5)}\n'
                        'Скор: ${(pt.speedMs * 3.6).toStringAsFixed(1)} км/ч  '
                        'Точн: ${pt.accuracyM.toStringAsFixed(0)} м',
                      ))
                  .toList(),
            ),
          const Gap(32),
          FilledButton.icon(
            onPressed: () => _exportDumpToFile(context, ref, trackingState,
                sessionsBox, markersBox),
            icon: const Icon(Icons.share),
            label: const Text('Экспортировать дамп'),
          ),
        ],
      ),
    );
  }

  /// FIX: экспорт дампа через файл — не обрезается при передаче
  Future<void> _exportDumpToFile(
    BuildContext context,
    WidgetRef ref,
    dynamic state,
    Box sessionsBox,
    Box markersBox,
  ) async {
    final sessionsAsync = ref.read(sessionsProvider);
    final sessions = sessionsAsync.valueOrNull ?? [];

    final buf = StringBuffer();
    buf.writeln('=== SLED Debug Dump ===');
    buf.writeln('Дата: ${DateTime.now()}');
    buf.writeln('Сессий в Hive: ${sessionsBox.length}');
    buf.writeln('Маркеров в Hive: ${markersBox.length}');
    buf.writeln('isTracking: ${state.isTracking}');
    buf.writeln('isPaused: ${state.isPaused}');
    buf.writeln(
        'Точек: ${state.session?.points.length ?? 0}');
    buf.writeln(
        'Дистанция: ${state.session?.distanceMeters ?? 0} м');
    buf.writeln('--- Все сессии ---');
    for (final s in sessions) {
      buf.writeln(
          '  [${s.activityType.label}] ${s.title} | '
          '${s.points.length} pts | '
          '${s.distanceMeters.toStringAsFixed(0)} м | '
          '${s.photos.length} фото');
    }
    if (state.session != null && state.session!.points.isNotEmpty) {
      buf.writeln('--- Последние GPS точки ---');
      for (final pt in state.session!.points.reversed.take(20)) {
        buf.writeln(
            '  ${pt.timestamp.toIso8601String()} | '
            '${pt.position.latitude.toStringAsFixed(6)}, '
            '${pt.position.longitude.toStringAsFixed(6)} | '
            '${(pt.speedMs * 3.6).toStringAsFixed(1)} км/ч | '
            '${pt.accuracyM.toStringAsFixed(0)} м точн');
      }
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path,
          'sled_dump_${DateTime.now().millisecondsSinceEpoch}.txt'));
      await file.writeAsString(buf.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'SLED Debug Dump',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
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
        title: const Text('Удалить ВСЕ данные?'),
        content: const Text('Все следы будут удалены безвозвратно.'),
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
          const SnackBar(content: Text('Данные удалены')),
        );
      }
    }
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
            width: 130,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
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
