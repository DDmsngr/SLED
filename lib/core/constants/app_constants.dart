/// Глобальные константы приложения SLED.
class AppConstants {
  AppConstants._();

  // Название приложения
  static const String appName = 'SLED';

  // GPS
  static const double gpsDistanceFilterMeters = 5.0;
  static const double minPointDistanceMeters = 2.0;
  static const double maxSpeedKmh = 150.0;

  // Карта
  static const double defaultZoom = 15.0;
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmAttribution = '© OpenStreetMap contributors';

  // Экспорт
  static const double collagePixelRatio = 3.0;
  static const int videoFps = 30;
  static const int videoBitrate = 4000000;

  // Hive box names
  static const String sessionsBox = 'sessions';
  static const String markersBox = 'markers';
}
