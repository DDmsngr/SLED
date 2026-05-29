import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/dev/dev_screen.dart';
import 'presentation/screens/detail/session_detail_screen.dart';
import 'presentation/screens/export/export_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/map/map_screen.dart';
import 'presentation/screens/stats/stats_screen.dart';
import 'presentation/screens/tracking/tracking_screen.dart';

class GpsTrackerApp extends ConsumerWidget {
  const GpsTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SLED',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/tracking', builder: (_, __) => const TrackingScreen()),
    GoRoute(
      path: '/session/:id',
      builder: (_, state) => SessionDetailScreen(
        sessionId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/export/:id',
      builder: (_, state) => ExportScreen(
        sessionId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
    GoRoute(path: '/map',   builder: (_, __) => const MapScreen()),
    GoRoute(path: '/dev',   builder: (_, __) => const DevScreen()),
  ],
);
