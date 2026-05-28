import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/activity_type.dart';
import '../../../domain/entities/track_session.dart';
import '../../providers/stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(globalStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Моя статистика')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (stats) {
          if (stats.totalSessions == 0) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                  Gap(16),
                  Text('Нет данных', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Итого ────────────────────────────────────────────────────
              _SectionTitle('Итого'),
              const Gap(8),
              Row(children: [
                Expanded(
                  child: _BigStatCard(
                    icon: Icons.route,
                    label: 'Дистанция',
                    value: formatDistance(stats.totalDistanceM),
                    color: theme.colorScheme.primaryContainer,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _BigStatCard(
                    icon: Icons.timer,
                    label: 'Время',
                    value: formatDuration(stats.totalDuration),
                    color: theme.colorScheme.secondaryContainer,
                  ),
                ),
              ]),
              const Gap(8),
              Row(children: [
                Expanded(
                  child: _BigStatCard(
                    icon: Icons.map,
                    label: 'Следов',
                    value: '${stats.totalSessions}',
                    color: theme.colorScheme.tertiaryContainer,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _BigStatCard(
                    icon: Icons.speed,
                    label: 'Ср. скорость',
                    value: stats.totalDuration.inSeconds > 0
                        ? '${(stats.totalDistanceM / stats.totalDuration.inSeconds * 3.6).toStringAsFixed(1)} км/ч'
                        : '—',
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ]),

              // ── Активность по неделям ─────────────────────────────────
              const Gap(20),
              _SectionTitle('Активность по неделям'),
              const Gap(8),
              _WeeklyChart(distances: stats.weeklyDistances),

              // ── По типам активности ───────────────────────────────────
              if (stats.countByType.isNotEmpty) ...[
                const Gap(20),
                _SectionTitle('По типу активности'),
                const Gap(8),
                ...stats.countByType.entries
                    .toList()
                    .sorted()
                    .map((e) => _ActivityRow(
                          type: e.key,
                          count: e.value,
                          total: stats.totalSessions,
                        )),
              ],

              // ── Рекорды ───────────────────────────────────────────────
              const Gap(20),
              _SectionTitle('Рекорды'),
              const Gap(8),
              if (stats.longestSession != null)
                _RecordCard(
                  icon: Icons.route,
                  label: 'Самый длинный',
                  value: formatDistance(stats.longestSession!.distanceMeters),
                  session: stats.longestSession!,
                ),
              if (stats.fastestSession != null) ...[
                const Gap(8),
                _RecordCard(
                  icon: Icons.speed,
                  label: 'Самый быстрый',
                  value: () {
                    final s = stats.fastestSession!;
                    final spd = s.duration.inSeconds > 0
                        ? s.distanceMeters / s.duration.inSeconds * 3.6
                        : 0.0;
                    return '${spd.toStringAsFixed(1)} км/ч ср.';
                  }(),
                  session: stats.fastestSession!,
                ),
              ],
              if (stats.mostPhotosSession != null) ...[
                const Gap(8),
                _RecordCard(
                  icon: Icons.photo_camera,
                  label: 'Больше всего фото',
                  value: '${stats.mostPhotosSession!.photos.length} фото',
                  session: stats.mostPhotosSession!,
                ),
              ],
              const Gap(32),
            ],
          );
        },
      ),
    );
  }
}

// ─── helpers ─────────────────────────────────────────────────────────────────

extension _SortEntries on List<MapEntry<ActivityType, int>> {
  List<MapEntry<ActivityType, int>> sorted() =>
      this..sort((a, b) => b.value.compareTo(a.value));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold));
}

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface),
            const Gap(6),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.type,
    required this.count,
    required this.total,
  });

  final ActivityType type;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frac = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(type.emoji, style: const TextStyle(fontSize: 18)),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(type.label, style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  Text('$count шт.', style: theme.textTheme.bodySmall),
                ]),
                const Gap(2),
                LinearProgressIndicator(
                  value: frac,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.session,
  });

  final IconData icon;
  final String label;
  final String value;
  final TrackSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/session/${session.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
                    Text(value,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(session.title,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

// Простая bar-chart для активности по неделям
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.distances});
  final List<double> distances;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxDist = distances.fold(0.0, (m, d) => d > m ? d : m);

    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(8, (i) {
          final isLast = i == 7;
          final frac = maxDist > 0 ? distances[i] / maxDist : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (distances[i] > 0)
                    Text(
                      formatDistance(distances[i]),
                      style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 8,
                          color: theme.colorScheme.outline),
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                    ),
                  const Gap(2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 64 * frac + 4,
                    decoration: BoxDecoration(
                      color: isLast
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primaryContainer,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ),
                  const Gap(2),
                  Text(
                    isLast ? 'Эта' : '-${7 - i}н',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
