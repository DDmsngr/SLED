import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:yandex_maps_mapkit/image.dart' as ymk_image;
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;

import '../../../core/constants/app_constants.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/mapkit_init.dart';
import '../../../core/utils/yandex_map_utils.dart';
import '../../../domain/entities/poi.dart';
import '../../../domain/entities/poi_type.dart';
import '../../providers/map_filter_provider.dart';
import '../../providers/poi_provider.dart';
import '../../widgets/lifecycle_yandex_map.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  ymk.MapWindow? _mapWindow;
  ymk.MapObjectCollection? _currentPosCollection;
  ymk.MapObjectCollection? _poiCollection;
  ymk.PlacemarkMapObject? _currentPosMark;

  final Map<PoiType, ymk_image.ImageProvider> _poiIcons = {};

  ymk_image.ImageProvider? _currentPosIcon;

  LatLng? _currentPos;
  bool _followUser = true;
  StreamSubscription<Position>? _posSub;

  // Map status tracking
  bool _mapCreated = false;
  bool _mapInteractive = false;
  bool _showTimeoutWarning = false;
  Timer? _timeoutTimer;
  bool _firstGpsFix = false;

  late final ymk.MapCameraListener _cameraListener;

  @override
  void initState() {
    super.initState();
    AppLogger.log('MapScreen', 'MapKit init: ${MapkitInit.status}');
    _loadIcons();
    _checkPermissionAndStart();

    _cameraListener = _CameraListenerImpl(onCamera: (reason) {
      if (!_mapInteractive && mounted) {
        AppLogger.log('Map', 'first camera event (reason=$reason) → tiles loading');
        setState(() {
          _mapInteractive = true;
          _showTimeoutWarning = false;
        });
      }
      if (reason == ymk.CameraUpdateReason.Gestures) {
        if (_followUser && mounted) setState(() => _followUser = false);
      }
    });

    // Если через 20 сек камера не заработала — показываем предупреждение
    _timeoutTimer = Timer(const Duration(seconds: 20), () {
      if (!_mapInteractive && mounted) {
        AppLogger.log('MapScreen', 'TIMEOUT: карта не загрузилась за 20 сек');
        setState(() => _showTimeoutWarning = true);
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _timeoutTimer?.cancel();
    _mapWindow?.map.removeCameraListener(_cameraListener);
    super.dispose();
  }

  Future<void> _loadIcons() async {
    AppLogger.log('MapScreen', 'loadIcons start');
    _currentPosIcon = await buildCircleMarker(const Color(0xFF00E5CC));
    for (final t in PoiType.values) {
      _poiIcons[t] = await buildEmojiMarker(t.emoji);
    }
    AppLogger.log('MapScreen', 'loadIcons done');
    if (!mounted) return;
    _refreshCurrentPosMarker();
    _refreshPoiMarkers(ref.read(poisProvider).value ?? const []);
  }

  Future<void> _checkPermissionAndStart() async {
    var permission = await Geolocator.checkPermission();
    AppLogger.log('MapScreen', 'GPS permission: $permission');

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      AppLogger.log('MapScreen', 'GPS after request: $permission');
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _startPositionWatch();
    } else {
      AppLogger.log('MapScreen', 'ERROR: GPS permission denied');
    }
  }

  void _startPositionWatch() {
    AppLogger.log('MapScreen', 'startPositionWatch');
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      final ll = LatLng(pos.latitude, pos.longitude);
      if (!_firstGpsFix) {
        _firstGpsFix = true;
        AppLogger.log('MapScreen',
            'first GPS fix: ${ll.latitude.toStringAsFixed(5)}, ${ll.longitude.toStringAsFixed(5)} '
            'acc=${pos.accuracy.toStringAsFixed(0)}m');
      }
      _currentPos = ll;
      _refreshCurrentPosMarker();
      if (_followUser) {
        _moveCameraTo(ll);
      }
    }, onError: (e) {
      AppLogger.log('MapScreen', 'GPS stream error: $e');
    });
  }

  void _onMapCreated(ymk.MapWindow window) {
    _mapWindow = window;
    _mapCreated = true;
    AppLogger.log('Map', 'onMapCreated OK');

    // Отдельные коллекции: текущая позиция и POI. Треки в этом экране не рисуем
    // (для треков есть TrackMapWidget).
    _currentPosCollection = window.map.mapObjects.addCollection();
    _poiCollection = window.map.mapObjects.addCollection();

    window.map.addCameraListener(_cameraListener);

    // Стартовая позиция камеры: либо текущая, либо fallback на центр РФ.
    // Fallback нужен чтобы тайлы начали грузиться даже без GPS.
    final start = _currentPos ?? const LatLng(55.7558, 37.6173); // Москва
    _moveCameraTo(start);

    _refreshCurrentPosMarker();
    _refreshPoiMarkers(ref.read(poisProvider).value ?? const []);

    if (mounted) setState(() {});
  }

  void _moveCameraTo(LatLng ll) {
    _mapWindow?.map.move(
      ymk.CameraPosition(
        ll.toYandex(),
        zoom: AppConstants.defaultZoom,
        azimuth: 0,
        tilt: 0,
      ),
    );
  }

  void _refreshCurrentPosMarker() {
    final col = _currentPosCollection;
    final icon = _currentPosIcon;
    final pos = _currentPos;
    if (col == null || icon == null || pos == null) return;

    if (_currentPosMark == null) {
      _currentPosMark = col.addPlacemarkWithPoint(pos.toYandex())
        ..setIcon(icon)
        ..setIconStyle(const ymk.IconStyle(scale: 0.8));
    } else {
      _currentPosMark!.geometry = pos.toYandex();
    }
  }

  void _refreshPoiMarkers(List<Poi> pois) {
    final col = _poiCollection;
    if (col == null) return;

    // Простейший подход: очистить и пересобрать. Для сотен POI можно
    // оптимизировать через diff, пока не нужно.
    col.clear();

    for (final poi in pois) {
      final icon = _poiIcons[poi.type];
      if (icon == null) continue;
      col.addPlacemarkWithPoint(poi.position.toYandex())
        ..setIconWithStyle(icon, const ymk.IconStyle(scale: 0.8))
        ..userData = poi.id
        ..addTapListener(_PoiTapListener(
          onTap: () => _showPoiDetail(context, poi),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Подписываемся на POI — при изменениях перерисовываем маркеры императивно.
    ref.listen(poisProvider, (_, next) {
      final list = next.value ?? const <Poi>[];
      _refreshPoiMarkers(list);
    });

    final filter = ref.watch(mapFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Разведка',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.white),
            tooltip: 'Мои следы',
            onPressed: () => context.push('/'),
          ),
          IconButton(
            icon: Icon(
              filter.tracksHidden ? Icons.layers_clear : Icons.layers,
              color: Colors.white,
            ),
            tooltip: filter.tracksHidden ? 'Показать треки' : 'Скрыть треки',
            onPressed: filter.tracksHidden
                ? ref.read(mapFilterProvider.notifier).showAllTracks
                : ref.read(mapFilterProvider.notifier).hideAllTracks,
          ),
        ],
      ),
      body: Stack(
        children: [
          LifecycleYandexMap(onMapCreated: _onMapCreated),

          // ── Оверлей: карта грузится ───────────────────────────────────
          if (!_mapInteractive)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _mapCreated ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF00E5CC)),
                          Gap(16),
                          Text('Загружаем карту...',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Предупреждение о таймауте ────────────────────────────────
          if (_showTimeoutWarning)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Material(
                borderRadius: BorderRadius.circular(12),
                color: Colors.orange.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                      const Gap(8),
                      const Expanded(
                        child: Text(
                          'Карта не отвечает. Проверь интернет или отключи VPN.',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () =>
                            setState(() => _showTimeoutWarning = false),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Кнопка возврата к позиции ────────────────────────────────
          if (!_followUser && _currentPos != null)
            Positioned(
              top: 100,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                onPressed: () {
                  setState(() => _followUser = true);
                  _moveCameraTo(_currentPos!);
                },
                backgroundColor: theme.colorScheme.surface,
                child: Icon(Icons.my_location, color: theme.colorScheme.primary),
              ),
            ),

          // ── Пынь FAB ─────────────────────────────────────────────────
          Positioned(
            bottom: 32,
            right: 24,
            child: FloatingActionButton.extended(
              heroTag: 'pyn',
              onPressed: _currentPos == null
                  ? null
                  : () => _showAddPoiSheet(context, _currentPos!),
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Пынь'),
              backgroundColor: theme.colorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPoiSheet(BuildContext context, LatLng position) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddPoiSheet(position: position),
    );
  }

  void _showPoiDetail(BuildContext context, Poi poi) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${poi.type.emoji} ${poi.type.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poi.comment != null && poi.comment!.isNotEmpty)
              Text(poi.comment!),
            const Gap(8),
            Text(
              '${poi.createdAt.day}.'
              '${poi.createdAt.month.toString().padLeft(2, '0')}'
              '.${poi.createdAt.year}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ref.read(addPoiProvider.notifier).deletePoi(poi.id);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

/// Импл ymk.MapCameraListener — принимает колбэк для удобства.
class _CameraListenerImpl extends ymk.MapCameraListener {
  _CameraListenerImpl({required this.onCamera});
  final void Function(ymk.CameraUpdateReason reason) onCamera;

  @override
  void onCameraPositionChanged(
    ymk.Map map,
    ymk.CameraPosition cameraPosition,
    ymk.CameraUpdateReason cameraUpdateReason,
    bool finished,
  ) {
    onCamera(cameraUpdateReason);
  }
}

/// Импл ymk.MapObjectTapListener — принимает колбэк, возвращает true всегда.
class _PoiTapListener extends ymk.MapObjectTapListener {
  _PoiTapListener({required this.onTap});
  final VoidCallback onTap;

  @override
  bool onMapObjectTap(ymk.MapObject mapObject, ymk.Point point) {
    onTap();
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AddPoiSheet extends ConsumerStatefulWidget {
  const _AddPoiSheet({required this.position});
  final LatLng position;

  @override
  ConsumerState<_AddPoiSheet> createState() => _AddPoiSheetState();
}

class _AddPoiSheetState extends ConsumerState<_AddPoiSheet> {
  PoiType _type = PoiType.viewpoint;
  final _commentCtrl = TextEditingController();
  bool _addPhoto = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addState = ref.watch(addPoiProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),
          Text('Добавить точку', style: theme.textTheme.titleMedium),
          const Gap(16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PoiType.values.map((t) {
              return FilterChip(
                label: Text('${t.emoji} ${t.label}'),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
              );
            }).toList(),
          ),
          const Gap(16),
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(
              labelText: 'Комментарий (необязательно)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const Gap(12),
          SwitchListTile(
            value: _addPhoto,
            onChanged: (v) => setState(() => _addPhoto = v),
            title: const Text('Прикрепить фото'),
            contentPadding: EdgeInsets.zero,
          ),
          const Gap(16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: addState.isLoading
                  ? null
                  : () async {
                      await ref.read(addPoiProvider.notifier).addPoi(
                            position: widget.position,
                            type: _type,
                            comment: _commentCtrl.text,
                            withPhoto: _addPhoto,
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
              icon: addState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Поставить точку'),
            ),
          ),
        ],
      ),
    );
  }
}
