import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/track_session.dart';

class StatsBarWidget extends StatelessWidget {
  const StatsBarWidget({
    super.key,
    required this.session,
    this.overrideDuration,
  });

  final TrackSession session;
  final Duration? overrideDuration; // плавный таймер из TrackingState

  double get _avgSpeed {
    final dur = overrideDuration ?? session.duration;
    final secs = dur.inSeconds;
    if (secs == 0) return 0;
    return (session.distanceMeters / secs) * 3.6;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = overrideDuration ?? session.duration;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(
              icon: Icons.route,
              label: 'Путь',
              value: formatDistance(session.distanceMeters),
            ),
            _divider(theme),
            _Stat(
              icon: Icons.timer,
              label: 'Время',
              value: formatDuration(duration),
            ),
            _divider(theme),
            _Stat(
              icon: Icons.speed,
              label: 'Скорость',
              value: '${_avgSpeed.toStringAsFixed(1)} км/ч',
            ),
            _divider(theme),
            _Stat(
              icon: Icons.photo_camera,
              label: 'Фото',
              value: '${session.photos.length}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(ThemeData t) => SizedBox(
        height: 32,
        child: VerticalDivider(color: t.colorScheme.outlineVariant),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const Gap(4),
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}
