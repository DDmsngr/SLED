import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/mapkit_factory.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';

/// Обёртка над [YandexMap] с автоматическим управлением жизненным циклом
/// нативного MapKit (onStart / onStop) и переключением ночного режима карты
/// в зависимости от темы приложения. По паттерну официального примера
/// yandex/mapkit-flutter-demo.
class LifecycleYandexMap extends StatefulWidget {
  const LifecycleYandexMap({
    super.key,
    required this.onMapCreated,
    this.onMapDispose,
    this.onResume,
  });

  final void Function(MapWindow window) onMapCreated;
  final VoidCallback? onMapDispose;
  /// Дёргается при возврате приложения из background (AppLifecycleState.resumed).
  /// Владельцу нужно на этот сигнал форсировать fetch текущей позиции и
  /// перецентровать камеру — за время сна OS позиция могла сильно уйти.
  final VoidCallback? onResume;

  @override
  State<LifecycleYandexMap> createState() => _LifecycleYandexMapState();
}

class _LifecycleYandexMapState extends State<LifecycleYandexMap> {
  late final AppLifecycleListener _lifecycle;
  MapWindow? _mapWindow;
  bool _mapkitActive = false;

  @override
  void initState() {
    super.initState();
    _startMapkit();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _startMapkit();
        _applyTheme();
        widget.onResume?.call();
      },
      onInactive: _stopMapkit,
    );
  }

  @override
  void dispose() {
    _stopMapkit();
    _lifecycle.dispose();
    widget.onMapDispose?.call();
    super.dispose();
  }

  void _startMapkit() {
    if (_mapkitActive) return;
    _mapkitActive = true;
    mapkit.onStart();
  }

  void _stopMapkit() {
    if (!_mapkitActive) return;
    _mapkitActive = false;
    mapkit.onStop();
  }

  void _applyTheme() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    _mapWindow?.map.nightModeEnabled = dark;
  }

  @override
  Widget build(BuildContext context) {
    return YandexMap(
      onMapCreated: (window) {
        _mapWindow = window;
        widget.onMapCreated(window);
        _applyTheme();
      },
      platformViewType: PlatformViewType.Hybrid,
    );
  }
}
