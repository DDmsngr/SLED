import 'dart:math';

import 'package:equatable/equatable.dart';

import 'track_point.dart';
import 'photo_marker.dart';
import 'activity_type.dart';

/// Полная сессия трекинга.
class TrackSession extends Equatable {
  const TrackSession({
    required this.id,
    required this.title,
    required this.startedAt,
    this.finishedAt,
    required this.points,
    required this.photos,
    required this.distanceMeters,
    this.activityType = ActivityType.walk,
    this.pausedDurationMs = 0,
    this.isSharedRoute = false,
    this.routeDescription = '',
  });

  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<TrackPoint> points;
  final List<PhotoMarker> photos;
  final double distanceMeters;
  final ActivityType activityType;
  final int pausedDurationMs;   // суммарное время на паузе в миллисекундах
  final bool isSharedRoute;     // помечен для шеринга
  final String routeDescription;

  /// Чистая продолжительность движения (без пауз).
  Duration get duration {
    final end = finishedAt ?? DateTime.now();
    final total = end.difference(startedAt);
    final paused = Duration(milliseconds: pausedDurationMs);
    return total - paused;
  }

  /// Максимальная скорость в км/ч.
  double get maxSpeedKmh {
    if (points.isEmpty) return 0;
    return points.map((p) => p.speedMs * 3.6).reduce(max);
  }

  /// Набор высоты (сумма положительных перепадов), метры.
  double get elevationGainM {
    if (points.length < 2) return 0;
    double gain = 0;
    for (int i = 1; i < points.length; i++) {
      final diff = points[i].altitudeM - points[i - 1].altitudeM;
      if (diff > 0.5) gain += diff; // игнорируем шум < 0.5 м
    }
    return gain;
  }

  /// Калории (ккал): MET × масса(кг) × время(ч).
  double caloriesKcal(double weightKg) {
    final hours = duration.inSeconds / 3600.0;
    return activityType.met * weightKg * hours;
  }

  TrackSession copyWith({
    String? title,
    DateTime? finishedAt,
    List<TrackPoint>? points,
    List<PhotoMarker>? photos,
    double? distanceMeters,
    ActivityType? activityType,
    int? pausedDurationMs,
    bool? isSharedRoute,
    String? routeDescription,
  }) =>
      TrackSession(
        id: id,
        title: title ?? this.title,
        startedAt: startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        points: points ?? this.points,
        photos: photos ?? this.photos,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        activityType: activityType ?? this.activityType,
        pausedDurationMs: pausedDurationMs ?? this.pausedDurationMs,
        isSharedRoute: isSharedRoute ?? this.isSharedRoute,
        routeDescription: routeDescription ?? this.routeDescription,
      );

  @override
  List<Object?> get props => [id];
}
