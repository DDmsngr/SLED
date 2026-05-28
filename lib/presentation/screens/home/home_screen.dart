import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/services/gpx_import_service.dart';
import '../../../domain/entities/activity_type.dart';
import '../../../domain/entities/gps_profile.dart';
import '../../../domain/entities/track_session.dart';
import '../../providers/session_provider.dart';
import '../../providers/tracking_provider.dart';

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
          child: const _SledLogo(compact: true),
        ),
        actions: [
          // Статистика
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Статистика',
            onPressed: () => context.push('/stats'),
          ),
          // Импорт / инфо
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'import') _importGpx(context);
              if (v == 'about') _showAbout(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_upload_outlined),
                  title: Text('Импортировать GPX'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('О приложении'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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
    final result = await showModalBottomSheet<_TrackingParams>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _StartTrackSheet(),
    );
    if (result != null && context.mounted) {
      unawaited(ref
          .read(trackingProvider.notifier)
          .startTracking(result.activityType, profile: result.profile));
      context.push('/tracking');
    }
  }

  Future<void> _importGpx(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;

      final session =
          await const GpxImportService().importFromFile(path);

      if (!context.mounted) return;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка: невалидный GPX файл')),
        );
        return;
      }

      await ref.read(sessionRepositoryProvider).saveSession(session);
      ref.invalidate(sessionsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Импортировано: ${session.title}')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка импорта: $e')),
        );
      }
    }
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'SLED',
      applicationVersion: '1.2.0',
      children: const [
        Text('GPS-трекер с фото-метками.\nРаботает полностью офлайн.'),
      ],
    );
  }
}

// ─── Параметры старта трека ───────────────────────────────────────────────────

class _TrackingParams {
  const _TrackingParams({required this.activityType, required this.profile});
  final ActivityType activityType;
  final GpsProfile profile;
}

// ─── Боттом-шит выбора типа + профиля ────────────────────────────────────────

class _StartTrackSheet extends StatefulWidget {
  const _StartTrackSheet();

  @override
  State<_StartTrackSheet> createState() => _StartTrackSheetState();
}

class _StartTrackSheetState extends State<_StartTrackSheet> {
  ActivityType _activityType = ActivityType.walk;
  GpsProfile _profile = GpsProfile.auto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),

          // Тип активности
          Text('Тип активности', style: theme.textTheme.titleMedium),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ActivityType.values.map((type) {
              final selected = _activityType == type;
              return FilterChip(
                label: Text('${type.emoji} ${type.label}'),
                selected: selected,
                onSelected: (_) => setState(() => _activityType = type),
              );
            }).toList(),
          ),

          const Gap(20),

          // GPS профиль
          Text('Профиль GPS', style: theme.textTheme.titleMedium),
          const Gap(10),
          Row(children: GpsProfile.values.map((p) {
            final selected = _profile == p;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ProfileChip(
                  profile: p,
                  selected: selected,
                  onTap: () => setState(() => _profile = p),
                ),
              ),
            );
          }).toList()),

          const Gap(24),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(
                  context, _TrackingParams(
                      activityType: _activityType, profile: _profile)),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Начать след'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final GpsProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(profile.emoji, style: const TextStyle(fontSize: 20)),
            const Gap(4),
            Text(profile.label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(profile.description,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Лого ────────────────────────────────────────────────────────────────────

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

// ─── Пустое состояние ─────────────────────────────────────────────────────────

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

// ─── Карточка сессии ──────────────────────────────────────────────────────────

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
