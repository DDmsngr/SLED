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
}
