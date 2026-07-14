import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/native_config.dart';
import '../../../data/datasources/isar_datasource.dart';
import '../../providers/poi_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/tracking_provider.dart';

class DevScreen extends ConsumerWidget {
  const DevScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingProvider);
    final sessionsAsync = ref.watch(sessionsProvider);
    final poisAsync = ref.watch(poisProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Mode'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Очистить все данные',
            onPressed: () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Конфигурация ────────────────────────────────────────────
          FutureBuilder<List<String>>(
            future: Future.wait([
              NativeConfig.yandexKeyPrefix(),
              NativeConfig.mapKitInitStatus(),
              NativeConfig.appPackage(),
              NativeConfig.appSha1(),
              NativeConfig.mapKitVersion(),
            ]),
            builder: (context, snap) {
              final d = snap.data ?? const ['...', '...', '...', '...', '...'];
              final prefix = d[0];
              final initStatus = d[1];
              final pkg = d[2];
              final sha1 = d[3];
              final mkVersion = d[4];
              final isTest = prefix == 'test_api' || prefix.startsWith('test');
              final initOk = initStatus.startsWith('ok:');
              return _Section(title: 'Конфигурация', children: [
                _Row('Yandex key (manifest)',
                    '$prefix... ${isTest ? '⚠️ TEST KEY' : '✅ real key'}'),
                _Row('MapKit init',
                    '$initStatus ${initOk ? '✅' : '❌'}'),
                _Row('MapKit version', mkVersion),
                _Row('App package', pkg),
                _Row('SHA-1 (release)', sha1),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 14),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    label: const Text('Скопировать SHA-1',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: sha1));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SHA-1 скопирован')),
                      );
                    },
                  ),
                ),
              ]);
            },
          ),
          const Gap(16),

          // ── Лог событий ─────────────────────────────────────────────
          StreamBuilder<List<LogEntry>>(
            stream: AppLogger.stream,
            initialData: AppLogger.entries,
            builder: (context, snapshot) {
              final logs = snapshot.data ?? [];
              return _Section(
                title: 'Лог (${logs.length})',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Скопировать',
                      onPressed: () {
                        final text = logs
                            .map((e) => '[${e.timeStr}][${e.tag}] ${e.message}')
                            .join('\n');
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Лог скопирован')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all, size: 18),
                      tooltip: 'Очистить',
                      onPressed: AppLogger.clear,
                    ),
                  ],
                ),
                children: logs.isEmpty
                    ? const [_Row('', 'пусто')]
                    : logs
                        .take(50)
                        .map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.timeStr,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                          fontFamily: 'monospace')),
                                  const Gap(4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(e.tag,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.deepOrange,
                                            fontFamily: 'monospace')),
                                  ),
                                  const Gap(4),
                                  Expanded(
                                    child: Text(e.message,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace')),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
              );
            },
          ),
          const Gap(16),

          _Section(title: 'Хранилище Isar', children: [
            _Row(
              'Сессий (Isar)',
              sessionsAsync.when(
                data: (s) => '${s.length}',
                loading: () => '...',
                error: (e, _) => 'Err',
              ),
            ),
            _Row(
              'POI (Isar)',
              poisAsync.when(
                data: (p) => '${p.length}',
                loading: () => '...',
                error: (e, _) => 'Err',
              ),
            ),
          ]),
          const Gap(16),
          _Section(title: 'Состояние трекинга', children: [
            _Row('status', trackingState.status.name),
            _Row('displayDuration', trackingState.displayDuration.toString()),
            _Row('currentPosition',
                trackingState.currentPosition?.toString() ?? 'null'),
            _Row('Точек', '${trackingState.session?.points.length ?? 0}'),
            _Row(
              'Дистанция',
              '${trackingState.session?.distanceMeters.toStringAsFixed(1) ?? 0} м',
            ),
            _Row(
              'Активность',
              trackingState.session?.activityType.label ?? 'нет',
            ),
          ]),
          const Gap(16),
          _Section(
            title: 'Все следы',
            children: sessionsAsync.when(
              data: (sessions) => sessions.isEmpty
                  ? const [_Row('Пусто', '')]
                  : sessions
                      .map((s) => _Row(s.title,
                          '${s.points.length} pts · ${s.photos.length} фото'))
                      .toList(),
              loading: () =>
                  const [Center(child: CircularProgressIndicator())],
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
            onPressed: () =>
                _exportDump(context, ref, trackingState, sessionsAsync),
            icon: const Icon(Icons.share),
            label: const Text('Экспортировать дамп'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить ВСЕ данные?'),
        content: const Text('Все следы и точки будут удалены безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить всё'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final db = IsarDatasource.instance.db;
      await db.writeTxn(() => db.clear());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные удалены')),
        );
      }
    }
  }

  Future<void> _exportDump(
    BuildContext context,
    WidgetRef ref,
    dynamic state,
    AsyncValue sessions,
  ) async {
    final sessionList = sessions.valueOrNull ?? [];
    final buf = StringBuffer();
    buf.writeln('=== SLED Debug Dump ===');
    buf.writeln('Дата: ${DateTime.now()}');
    buf.writeln('status: ${state.status.name}');
    buf.writeln('Точек: ${state.session?.points.length ?? 0}');
    buf.writeln('Дистанция: ${state.session?.distanceMeters ?? 0} м');
    buf.writeln('--- Все сессии ---');
    for (final s in sessionList) {
      buf.writeln('  [${s.activityType.label}] ${s.title} | '
          '${s.points.length} pts | '
          '${s.distanceMeters.toStringAsFixed(0)} м | '
          '${s.photos.length} фото');
    }
    if (state.session != null && state.session!.points.isNotEmpty) {
      buf.writeln('--- Последние GPS точки ---');
      for (final pt in state.session!.points.reversed.take(20)) {
        buf.writeln('  ${pt.timestamp.toIso8601String()} | '
            '${pt.position.latitude.toStringAsFixed(6)}, '
            '${pt.position.longitude.toStringAsFixed(6)} | '
            '${(pt.speedMs * 3.6).toStringAsFixed(1)} км/ч | '
            '${pt.accuracyM.toStringAsFixed(0)} м');
      }
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          p.join(dir.path, 'sled_dump_${DateTime.now().millisecondsSinceEpoch}.txt'));
      await file.writeAsString(buf.toString());
      await Share.shareXFiles([XFile(file.path)], subject: 'SLED Debug Dump');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: Colors.deepOrange)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
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
