/// Тип активности для маршрута.
enum ActivityType {
  walk,
  run,
  bike,
  rollerblades,
  car,
  boat,
  ski,
  other;

  String get label => switch (this) {
        ActivityType.walk         => 'Пешком',
        ActivityType.run          => 'Бег',
        ActivityType.bike         => 'Велосипед',
        ActivityType.rollerblades => 'Ролики',
        ActivityType.car          => 'Машина',
        ActivityType.boat         => 'Катер',
        ActivityType.ski          => 'Лыжи',
        ActivityType.other        => 'Другое',
      };

  String get emoji => switch (this) {
        ActivityType.walk         => '🚶',
        ActivityType.run          => '🏃',
        ActivityType.bike         => '🚴',
        ActivityType.rollerblades => '⛸️',
        ActivityType.car          => '🚗',
        ActivityType.boat         => '⛵',
        ActivityType.ski          => '⛷️',
        ActivityType.other        => '📍',
      };

  /// MET (Metabolic Equivalent of Task) для расчёта калорий.
  double get met => switch (this) {
        ActivityType.walk         => 3.5,
        ActivityType.run          => 8.0,
        ActivityType.bike         => 6.0,
        ActivityType.rollerblades => 7.0,
        ActivityType.car          => 1.5,
        ActivityType.boat         => 3.0,
        ActivityType.ski          => 6.0,
        ActivityType.other        => 4.0,
      };
}
