import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track_session.dart';
import '../../domain/entities/activity_type.dart';
import 'session_provider.dart';

class GlobalStats {
  const GlobalStats({
    required this.totalDistanceM,
    required this.totalDuration,
    required this.totalSessions,
    required this.countByType,
    required this.longestSession,
    required this.fastestSession,
    required this.mostPhotosSession,
    required this.weeklyDistances,
  });

  final double totalDistanceM;
  final Duration totalDuration;
  final int totalSessions;
  final Map<ActivityType, int> countByType;
  final TrackSession? longestSession;
  final TrackSession? fastestSession;
  final TrackSession? mostPhotosSession;

  /// Суммарная дистанция за каждую из последних 8 недель (старая → новая).
  final List<double> weeklyDistances;
}

final globalStatsProvider = FutureProvider<GlobalStats>((ref) async {
  final sessions = await ref.watch(sessionsProvider.future);
  return _compute(sessions);
});

GlobalStats _compute(List<TrackSession> sessions) {
  if (sessions.isEmpty) {
    return GlobalStats(
      totalDistanceM: 0,
      totalDuration: Duration.zero,
      totalSessions: 0,
      countByType: {},
      longestSession: null,
      fastestSession: null,
      mostPhotosSession: null,
      weeklyDistances: List.filled(8, 0),
    );
  }

  double totalDist = 0;
  Duration totalDur = Duration.zero;
  final countByType = <ActivityType, int>{};

  for (final s in sessions) {
    totalDist += s.distanceMeters;
    totalDur += s.duration;
    countByType[s.activityType] = (countByType[s.activityType] ?? 0) + 1;
  }

  final finished = sessions.where((s) => s.finishedAt != null).toList();

  final longest = finished.isEmpty
      ? null
      : finished.reduce((a, b) =>
          a.distanceMeters >= b.distanceMeters ? a : b);

  final fastest = finished.isEmpty
      ? null
      : finished
          .where((s) => s.duration.inSeconds > 0)
          .fold<TrackSession?>(null, (best, s) {
            final spd = s.distanceMeters / s.duration.inSeconds;
            if (best == null) return s;
            final bestSpd = best.distanceMeters / best.duration.inSeconds;
            return spd >= bestSpd ? s : best;
          });

  final mostPhotos = sessions.reduce((a, b) =>
      a.photos.length >= b.photos.length ? a : b);

  final weekly = _weeklyDistances(sessions);

  return GlobalStats(
    totalDistanceM: totalDist,
    totalDuration: totalDur,
    totalSessions: sessions.length,
    countByType: countByType,
    longestSession: longest,
    fastestSession: fastest,
    mostPhotosSession: mostPhotos.photos.isNotEmpty ? mostPhotos : null,
    weeklyDistances: weekly,
  );
}

List<double> _weeklyDistances(List<TrackSession> sessions) {
  final now = DateTime.now();
  // Начало текущей недели (понедельник 00:00).
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekMonday = DateTime(weekStart.year, weekStart.month, weekStart.day);

  final distances = List<double>.filled(8, 0);
  for (final s in sessions) {
    final diff = weekMonday.difference(
        DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day));
    final weeksAgo = (diff.inDays / 7).floor();
    if (weeksAgo >= 0 && weeksAgo < 8) {
      distances[7 - weeksAgo] += s.distanceMeters;
    }
  }
  return distances;
}
