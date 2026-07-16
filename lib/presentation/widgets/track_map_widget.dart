import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:yandex_maps_mapkit/image.dart' as ymk_image;
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/yandex_map_utils.dart';
import '../../domain/entities/photo_marker.dart';
import '../../domain/entities/poi.dart';
import '../../domain/entities/poi_type.dart';
import '../../domain/entities/track_session.dart';
import '../providers/poi_provider.dart';
import 'lifecycle_yandex_map.dart';

class TrackMapWidget extends ConsumerStatefulWidget {
  const TrackMapWidget({
    super.key,
    required this.session,
    this.currentPosition,
    this.onMarkerTap,
    this.interactive = true,
    this.followUser = false,
    this.onManualPan,
    this.onMapReady,
  });

  final TrackSession session;
  final LatLng? currentPosition;
  final void Function(PhotoMarker)? onMarkerTap;
  final bool interactive;
  final bool followUser;
  final VoidCallback? onManualPan;
  final VoidCallback? onMapReady;

  @override
  ConsumerState<TrackMapWidget> createState() => _TrackMapWidgetState();
}

class _TrackMapWidgetState extends ConsumerState<TrackMapWidget> {
  ymk.MapWindow? _mapWindow;

  // Отдельные коллекции по слоям — так проще их обновлять императивно.
  ymk.MapObjectCollection? _trackCol;
  ymk.MapObjectCollection? _markersCol;

  ymk.PolylineMapObject? _trackLine;
  ymk.PlacemarkMapObject? _currentMark;

  ymk_image.ImageProvider? _currentPosIcon;
  ymk_image.ImageProvider? _startIcon;
  ymk_image.ImageProvider? _cameraIcon;
  final Map<PoiType, ymk_image.ImageProvider> _poiIcons = {};
  bool _iconsReady = false;

  late final ymk.MapCameraListener _cameraListener;

  @override
  void initState() {
    super.initState();
    _loadIcons();
    _cameraListener = _CameraListenerImpl(onReason: (r) {
      if (r == ymk.CameraUpdateReason.Gestures) {
        widget.onManualPan?.call();
      }
    });
  }

  @override
  void dispose() {
    _mapWindow?.map.removeCameraListener(_cameraListener);
    super.dispose();
  }

  Future<void> _loadIcons() async {
    _currentPosIcon = await buildCircleMarker(const Color(0xFF00E5CC));
    _startIcon = await buildCircleMarker(Colors.green, size: 36);
    _cameraIcon = await buildEmojiMarker('📷');
    for (final t in PoiType.values) {
      _poiIcons[t] = await buildEmojiMarker(t.emoji);
    }
    if (!mounted) return;
    setState(() => _iconsReady = true);
    _rebuildMarkers();
  }

  @override
  void didUpdateWidget(TrackMapWidget old) {
    super.didUpdateWidget(old);
    // Обновление позиции
    if (widget.currentPosition != old.currentPosition) {
      _updateCurrentMark();
      if (widget.followUser && widget.currentPosition != null) {
        _moveCamera(widget.currentPosition!);
      }
    }
    // Начали следить за юзером
    if (widget.followUser && !old.followUser && widget.currentPosition != null) {
      _moveCamera(widget.currentPosition!);
    }
    // Сессия изменилась (например, добавились точки трека или фото)
    if (widget.session != old.session) {
      _rebuildTrackLine();
      _rebuildMarkers();
    }
  }

  void _onMapCreated(ymk.MapWindow window) {
    _mapWindow = window;
    _trackCol = window.map.mapObjects.addCollection();
    _markersCol = window.map.mapObjects.addCollection();
    window.map.addCameraListener(_cameraListener);

    _rebuildTrackLine();
    _rebuildMarkers();

    // Fit к треку, либо к текущей позиции, либо fallback на центр РФ.
    final pts = widget.session.points.map((p) => p.position).toList();
    if (pts.length > 1) {
      _fitTrack(pts);
    } else if (widget.currentPosition != null) {
      _moveCamera(widget.currentPosition!);
    } else if (pts.isNotEmpty) {
      _moveCamera(pts.first);
    } else {
      _moveCamera(const LatLng(55.7558, 37.6173)); // Москва — чтобы тайлы поехали
    }

    widget.onMapReady?.call();
  }

  void _moveCamera(LatLng ll) {
    _mapWindow?.map.move(
      ymk.CameraPosition(
        ll.toYandex(),
        zoom: AppConstants.defaultZoom,
        azimuth: 0,
        tilt: 0,
      ),
      animation: const ymk.Animation(type: ymk.AnimationType.Smooth, duration: 0.3),
    );
  }

  void _fitTrack(List<LatLng> pts) {
    if (pts.length < 2 || _mapWindow == null) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bbox = ymk.BoundingBox(
      LatLng(minLat, minLng).toYandex(),
      LatLng(maxLat, maxLng).toYandex(),
    );
    final camera = _mapWindow!.map
        .cameraPositionForGeometry(ymk.Geometry.fromBoundingBox(bbox));
    _mapWindow!.map.move(
      camera,
      animation: const ymk.Animation(type: ymk.AnimationType.Smooth, duration: 0.5),
    );
  }

  void _rebuildTrackLine() {
    final col = _trackCol;
    if (col == null) return;
    final pts = widget.session.points.map((p) => p.position.toYandex()).toList();
    // Убираем старую линию, чтобы обновить геометрию без визуальных артефактов.
    if (_trackLine != null) {
      col.remove(_trackLine!);
      _trackLine = null;
    }
    if (pts.length < 2) return;

    final scheme = Theme.of(context).colorScheme;
    _trackLine = col.addPolylineWithGeometry(ymk.Polyline(pts))
      ..style = ymk.LineStyle(
        strokeWidth: 4.0,
        outlineWidth: 1.5,
        outlineColor: scheme.primary.withValues(alpha: 0.3),
      )
      ..setStrokeColor(scheme.primary);
  }

  void _rebuildMarkers() {
    final col = _markersCol;
    if (col == null || !_iconsReady) return;

    col.clear();
    _currentMark = null;

    final points = widget.session.points.map((p) => p.position).toList();

    if (points.isNotEmpty) {
      col.addPlacemarkWithPoint(points.first.toYandex())
          .setIconWithStyle(_startIcon!, const ymk.IconStyle(scale: 0.7));
    }

    if (widget.currentPosition != null) {
      _currentMark = col.addPlacemarkWithPoint(widget.currentPosition!.toYandex())
        ..setIconWithStyle(_currentPosIcon!, const ymk.IconStyle(scale: 0.8));
    }

    // POI-слой
    final pois = ref.read(poisProvider).value ?? const <Poi>[];
    for (final poi in pois) {
      final icon = _poiIcons[poi.type];
      if (icon == null) continue;
      col.addPlacemarkWithPoint(poi.position.toYandex())
        ..setIconWithStyle(icon, const ymk.IconStyle(scale: 0.8))
        ..addTapListener(_TapListener(onTap: () => _showPoiSnack(context, poi)));
    }

    // Фото-маркеры
    for (final photo in widget.session.photos) {
      col.addPlacemarkWithPoint(photo.position.toYandex())
        ..setIconWithStyle(_cameraIcon!, const ymk.IconStyle(scale: 0.8))
        ..addTapListener(_TapListener(onTap: () {
          widget.onMarkerTap?.call(photo);
          _showPhotoPreview(context, photo);
        }));
    }
  }

  void _updateCurrentMark() {
    final col = _markersCol;
    final icon = _currentPosIcon;
    if (col == null || icon == null) return;
    final pos = widget.currentPosition;
    if (pos == null) {
      if (_currentMark != null) {
        col.remove(_currentMark!);
        _currentMark = null;
      }
      return;
    }
    if (_currentMark == null) {
      _currentMark = col.addPlacemarkWithPoint(pos.toYandex())
        ..setIconWithStyle(icon, const ymk.IconStyle(scale: 0.8));
    } else {
      _currentMark!.geometry = pos.toYandex();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Реагируем на изменения POI в реестре — перерисуем маркеры.
    ref.listen(poisProvider, (_, __) => _rebuildMarkers());

    return AbsorbPointer(
      absorbing: !widget.interactive,
      child: LifecycleYandexMap(
        onMapCreated: _onMapCreated,
        onResume: () {
          // При возврате из background — заново перецентровать камеру,
          // потому что за время сна OS позиция могла уйти далеко от
          // видимой области.
          if (widget.followUser && widget.currentPosition != null) {
            _moveCamera(widget.currentPosition!);
          } else {
            final pts = widget.session.points.map((p) => p.position).toList();
            if (pts.length > 1) _fitTrack(pts);
          }
        },
      ),
    );
  }

  void _showPoiSnack(BuildContext context, Poi poi) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${poi.type.emoji} ${poi.type.label}'
          '${poi.comment != null ? ': ${poi.comment}' : ''}'),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showPhotoPreview(BuildContext context, PhotoMarker photo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(
                File(photo.filePath),
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  formatDateTime(photo.timestamp),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraListenerImpl extends ymk.MapCameraListener {
  _CameraListenerImpl({required this.onReason});
  final void Function(ymk.CameraUpdateReason) onReason;

  @override
  void onCameraPositionChanged(
    ymk.Map map,
    ymk.CameraPosition cameraPosition,
    ymk.CameraUpdateReason cameraUpdateReason,
    bool finished,
  ) {
    onReason(cameraUpdateReason);
  }
}

class _TapListener extends ymk.MapObjectTapListener {
  _TapListener({required this.onTap});
  final VoidCallback onTap;

  @override
  bool onMapObjectTap(ymk.MapObject mapObject, ymk.Point point) {
    onTap();
    return true;
  }
}
