import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import '../../../core/utils/date_formatter.dart';
import '../../providers/tracking_provider.dart';
import '../../widgets/track_map_widget.dart';
import '../../widgets/stats_bar_widget.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  bool _followUser = true;
  bool _mapReady = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingProvider);
    final notifier = ref.read(trackingProvider.notifier);
    final theme = Theme.of(context);

    ref.listen(trackingProvider, (_, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        elevation: 0,
        leading: BackButton(
          color: Colors.white,
          onPressed: () {
            if (state.isTracking) {
              _confirmExit(context, notifier);
            } else {
              context.pop();
            }
          },
        ),
        title: state.isTracking
            ? _TrackingHeader(state: state)
            : const Text('SLED',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (state.session != null && !state.isTracking)
            IconButton(
              icon: const Icon(Icons.ios_share, color: Colors.white),
              onPressed: () => context.push('/export/${state.session!.id}'),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (state.session != null)
            TrackMapWidget(
              session: state.session!,
              currentPosition: state.currentPosition,
              followUser: _followUser,
              onManualPan: () => setState(() => _followUser = false),
              onMapReady: () => setState(() => _mapReady = true),
            )
          else
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route, size: 64, color: Colors.grey),
                    Gap(16),
                    Text('Нажмите «Начать след»',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

          // Оверлей загрузки карты
          if (state.session != null && !_mapReady)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF00E5CC),
                      strokeWidth: 3,
                    ),
                    const Gap(20),
                    Text('Загружаем карту...',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white)),
                    const Gap(8),
                    Text('Ищем GPS-сигнал',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white60)),
                  ],
                ),
              ),
            ),

          // Оверлей инициализации: foreground service + создание сессии (~3–5 с).
          // Перекрывает весь экран, предотвращая мигание старым состоянием.
          if (state.isInitializing)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        color: Color(0xFF00E5CC),
                        strokeWidth: 3,
                      ),
                    ),
                    const Gap(24),
                    Text(
                      'Запускаем трекинг...',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                    const Gap(6),
                    Text(
                      'Ищем GPS-сигнал',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),

          if (state.isTracking && !_followUser && _mapReady)
            Positioned(
              top: 100, right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                onPressed: () => setState(() => _followUser = true),
                backgroundColor: theme.colorScheme.surface,
                child: Icon(Icons.my_location, color: theme.colorScheme.primary),
              ),
            ),

          if (state.session != null && _mapReady)
            Positioned(
              bottom: 120, left: 0, right: 0,
              child: StatsBarWidget(
                session: state.session!,
                overrideDuration: state.displayDuration,
                currentSpeedKmh:
                    state.isActivelyRecording ? state.currentSpeedKmh : null,
              ),
            ),

          Positioned(
            bottom: 24, left: 24, right: 24,
            child: _ControlBar(
              state: state,
              notifier: notifier,
              onStarted: () => setState(() {
                _followUser = true;
                _mapReady = false;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context, TrackingNotifier notifier) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Запись активна'),
        content: const Text('Завершить след и выйти?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Продолжить')),
          FilledButton(onPressed: () => Navigator.pop(context, 'stop'), child: const Text('Завершить')),
        ],
      ),
    );
    if (choice == 'stop' && context.mounted) {
      await notifier.stopTracking();
      if (context.mounted) context.pop();
    }
  }
}

class _TrackingHeader extends StatelessWidget {
  const _TrackingHeader({required this.state});
  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.isPaused)
          const Icon(Icons.pause_circle, color: Colors.orange, size: 16)
        else
          _PulseDot(),
        const Gap(6),
        Text(
          state.isPaused
              ? 'Пауза  ${formatDuration(state.displayDuration)}'
              : 'Записываю  ${formatDuration(state.displayDuration)}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}

class _ControlBar extends ConsumerWidget {
  const _ControlBar({required this.state, required this.notifier, required this.onStarted});
  final TrackingState state;
  final TrackingNotifier notifier;
  final VoidCallback onStarted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (!state.isTracking) {
      return FilledButton.icon(
        onPressed: () { if (state.session == null) context.pop(); onStarted(); },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Начать след'),
      );
    }
    return Row(
      children: [
        FloatingActionButton(
          heroTag: 'pause', mini: true,
          backgroundColor: theme.colorScheme.secondaryContainer,
          onPressed: state.isPaused ? notifier.resumeTracking : notifier.pauseTracking,
          child: Icon(state.isPaused ? Icons.play_arrow : Icons.pause,
              color: theme.colorScheme.onSecondaryContainer),
        ),
        const Gap(12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              final sessionId = state.session?.id;
              unawaited(notifier.stopTracking().then((_) {
                if (context.mounted && sessionId != null) context.push('/export/$sessionId');
              }));
            },
            icon: const Icon(Icons.stop),
            label: const Text('Завершить след'),
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          ),
        ),
        const Gap(12),
        FloatingActionButton(
          heroTag: 'photo', mini: true,
          onPressed: state.isPaused ? null : notifier.takePhoto,
          child: const Icon(Icons.photo_camera),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _ctrl,
    child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
  );
}
