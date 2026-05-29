/// Глобальные константы приложения SLED.
class AppConstants {
  AppConstants._();

  static const String appName = 'SLED';

  // GPS
  static const double gpsDistanceFilterMeters = 5.0;
  static const double minPointDistanceMeters = 2.0;
  static const double maxSpeedKmh = 150.0;

  // Карта
  static const double defaultZoom = 15.0;

  // Yandex MapKit API key.
  // Получить бесплатный ключ: https://developer.tech.yandex.ru/
  // Передать через: flutter run --dart-define=YANDEX_MAPKIT_API_KEY=ваш_ключ
  // Для тестирования без ключа карта работает с водяным знаком.
  static const String yandexApiKey = String.fromEnvironment(
    'YANDEX_MAPKIT_API_KEY',
    defaultValue: 'test_api_key',
  );

  // Экспорт
  static const double collagePixelRatio = 3.0;
  static const int videoFps = 30;
  static const int videoBitrate = 4000000;
}
