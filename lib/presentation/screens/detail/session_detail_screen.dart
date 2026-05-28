import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/photo_marker.dart';
import '../../../domain/entities/track_session.dart';
import '../../providers/session_provider.dart';
import '../../widgets/track_map_widget.dart';
import '../../widgets/stats_bar_widget.dart';
import '../../widgets/speed_chart_widget.dart';

/// Детальный просмотр завершённой сессии.
class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  // Вес пользователя для расчёта калорий (можно изменить слайдером).
  double _weightKg = 70;

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionByIdProvider(widget.sessionId));

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
                        context.push('/export/${widget.sessionId}'),
                  ),
                ],
              ),

              // Карта
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: TrackMapWidget(
                      session: session, interactive: true),
                ),
              ),

              // Базовая панель (путь / время / скорость / фото)
              SliverToBoxAdapter(
                  child: StatsBarWidget(session: session)),

              // Детальная статистика
              SliverToBoxAdapter(
                child: _DetailStatsCard(
                  session: session,
                  weightKg: _weightKg,
                  onWeightChanged: (v) => setState(() => _weightKg = v),
                ),
              ),

              // График скорости
              if (session.points.length >= 2)
                SliverToBoxAdapter(
                  child: SpeedChartWidget(session: session),
                ),

              // Фотографии
              if (session.photos.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Фотографии',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _PhotoTile(photo: session.photos[i]),
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
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
      ),
    );
  }
}

// ─── Детальная карточка статистики ───────────────────────────────────────────

class _DetailStatsCard extends StatelessWidget {
  const _DetailStatsCard({
    required this.session,
    required this.weightKg,
    required this.onWeightChanged,
  });

  final TrackSession session;
  final double weightKg;
  final ValueChanged<double> onWeightChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avgSpd = session.duration.inSeconds > 0
        ? session.distanceMeters / session.duration.inSeconds * 3.6
        : 0.0;
    final calories = session.caloriesKcal(weightKg);
    final hasAltitude = session.points.any((p) => p.altitudeM != 0);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Подробная статистика',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Gap(12),
            _grid([
              _StatItem(
                icon: Icons.speed,
                label: 'Ср. скорость',
                value: '${avgSpd.toStringAsFixed(1)} км/ч',
              ),
              _StatItem(
                icon: Icons.flash_on,
                label: 'Макс. скорость',
                value: '${session.maxSpeedKmh.toStringAsFixed(1)} км/ч',
              ),
              if (hasAltitude)
                _StatItem(
                  icon: Icons.trending_up,
                  label: 'Набор высоты',
                  value: '${session.elevationGainM.toStringAsFixed(0)} м',
                ),
              _StatItem(
                icon: Icons.local_fire_department,
                label: 'Калории',
                value: '${calories.toStringAsFixed(0)} ккал',
              ),
              _StatItem(
                icon: Icons.location_on,
                label: 'Точек GPS',
                value: '${session.points.length}',
              ),
              _StatItem(
                icon: Icons.photo_camera,
                label: 'Фото',
                value: '${session.photos.length}',
              ),
            ]),

            const Gap(12),
            const Divider(height: 1),
            const Gap(10),

            // Слайдер веса для калорий
            Row(children: [
              Icon(Icons.person, size: 18,
                  color: theme.colorScheme.outline),
              const Gap(8),
              Text('Вес: ${weightKg.toInt()} кг',
                  style: theme.textTheme.bodySmall),
              Expanded(
                child: Slider(
                  value: weightKg,
                  min: 40,
                  max: 150,
                  divisions: 110,
                  onChanged: onWeightChanged,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<Widget> items) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(Row(children: [
        Expanded(child: items[i]),
        if (i + 1 < items.length) Expanded(child: items[i + 1]),
      ]));
      if (i + 2 < items.length) rows.add(const Gap(8));
    }
    return Column(children: rows);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const Gap(6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ],
    );
  }
}

// ─── Фото ────────────────────────────────────────────────────────────────────

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
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(File(photo.filePath),
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image,
                          color: Colors.white, size: 64)),
            ),
            Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context))),
            Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                    child: Text(formatDateTime(photo.timestamp),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)))),
          ],
        ),
      ),
    );
  }
}
