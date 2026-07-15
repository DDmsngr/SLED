/// Статус инициализации Yandex MapKit — устанавливается в main.dart
/// и читается через NativeConfig / Dev Mode. Раньше инициализация была
/// в MainApplication.kt через MapKitFactory.setApiKey, теперь всё в Dart.
abstract class MapkitInit {
  static String status = 'not_started';
}
