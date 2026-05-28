import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../../core/utils/date_formatter.dart';
import '../../providers/session_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../../domain/entities/track_session.dart';
import '../../../domain/entities/activity_type.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _logoTapCount = 0;
  DateTime? _lastLogoTap;

  void _onLogoTap() {
    final now = DateTime.now();
    if (_lastLogoTap != null &&
        now.difference(_lastLogoTap!) > const Duration(seconds: 2)) {
      _logoTapCount = 0;
    }
    _lastLogoTap = now;
    _logoTapCount++;
    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      context.push('/dev');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final isTracking = ref.watch(trackingProvider).isTracking;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onLogoTap,
          child: _SledLogo(compact: true),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'SLED',
              applicationVersion: '1.0.0',
              children: const [
                Text('GPS-трекер с фото-метками.\nРаботает полностью офлайн.'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => isTracking
            ? context.push('/tracking')
            : _showActivityPicker(context),
        icon: Icon(isTracking ? Icons.play_arrow : Icons.add),
        label: Text(isTracking ? 'Продолжить след' : 'Начать след'),
        backgroundColor: isTracking
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary,
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (sessions) {
          if (sessions.isEmpty) return const _EmptyState();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text('Мои следы',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${sessions.length}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(sessionsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: sessions.length,
                    itemBuilder: (_, i) =>
                        _SessionCard(session: sessions[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showActivityPicker(BuildContext context) async {
    final type = await showModalBottomSheet<ActivityType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ActivityPickerSheet(),
    );
    if (type != null && context.mounted) {
      ref.read(trackingProvider.notifier).startTracking(type);
      context.push('/tracking');
    }
  }
}

// ── SLED Logo Widget ──────────────────────────────────────────────────────────
class _SledLogo extends StatelessWidget {
  const _SledLogo({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route, color: color, size: 22),
          const Gap(6),
          Text('SLED',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 3,
                  color: color)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.route, color: color, size: 64),
        const Gap(8),
        Text('SLED',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 40,
                letterSpacing: 8,
                color: color)),
        Text('GPS ТРЕКЕР',
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 4,
                color: color.withOpacity(0.6))),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _SledLogo(),
          const Gap(40),
          Text('Нет следов',
              style: Theme.of(context).textTheme.headlineSmall),
          const Gap(8),
          Text('Нажмите «Начать след»',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}

// ── Activity Picker ───────────────────────────────────────────────────────────
class _ActivityPickerSheet extends StatelessWidget {
  const _ActivityPickerSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),
          Text('Тип активности',
              style: Theme.of(context).textTheme.titleMedium),
          const Gap(12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ActivityType.values.map((type) {
              return ActionChip(
                label: Text('${type.emoji} ${type.label}'),
                onPressed: () => Navigator.pop(context, type),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Session Card ──────────────────────────────────────────────────────────────
class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});
  final TrackSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/session/${session.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(session.activityType.emoji,
                    style: const TextStyle(fontSize: 20)),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.title,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis),
                    const Gap(2),
                    Text(
                      '${formatDistance(session.distanceMeters)}  ·  '
                      '${formatDuration(session.duration)}  ·  '
                      '${session.photos.length} фото',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      formatDateTime(session.startedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить след?'),
        content: const Text('Все данные и фотографии будут удалены.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(sessionRepositoryProvider).deleteSession(session.id);
      ref.invalidate(sessionsProvider);
    }
  }
}
