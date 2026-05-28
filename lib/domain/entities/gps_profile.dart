import 'package:geolocator/geolocator.dart';

/// Профиль энергосбережения GPS.
enum GpsProfile {
  auto,
  hike,
  eco;

  String get label => switch (this) {
        GpsProfile.auto => 'Авто',
        GpsProfile.hike => 'Поход',
        GpsProfile.eco  => 'Эко',
      };

  String get description => switch (this) {
        GpsProfile.auto => 'каждые 1–2 сек',
        GpsProfile.hike => 'каждые 30 сек',
        GpsProfile.eco  => 'каждые 60 сек',
      };

  String get emoji => switch (this) {
        GpsProfile.auto => '⚡',
        GpsProfile.hike => '🥾',
        GpsProfile.eco  => '🌿',
      };

  Duration get interval => switch (this) {
        GpsProfile.auto => const Duration(seconds: 1),
        GpsProfile.hike => const Duration(seconds: 30),
        GpsProfile.eco  => const Duration(seconds: 60),
      };

  double get distanceFilterM => switch (this) {
        GpsProfile.auto => 5.0,
        GpsProfile.hike => 20.0,
        GpsProfile.eco  => 50.0,
      };

  LocationAccuracy get accuracy => switch (this) {
        GpsProfile.auto => LocationAccuracy.bestForNavigation,
        GpsProfile.hike => LocationAccuracy.high,
        GpsProfile.eco  => LocationAccuracy.medium,
      };
}
