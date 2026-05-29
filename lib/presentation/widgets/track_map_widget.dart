import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/yandex_map_utils.dart';
import '../../domain/entities/photo_marker.dart';
import '../../domain/entities/poi.dart';
import '../../domain/entities/poi_type.dart';
import '../../domain/entities/track_session.dart';
import '../providers/poi_provider.dart';

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
  YandexMapController? _mapController;

  BitmapDescriptor? _currentPosIcon;
  BitmapDescriptor? _startIcon;
  BitmapDescriptor? _cameraIcon;
  final Map<PoiType, BitmapDescriptor> _poiIcons = {};
  bool _iconsReady = false;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    _currentPosIcon = await buildCircleMarker(const Color(0xFF00E5CC));
    _startIcon = await buildCircleMarker(Colors.green, size: 36);
    _cameraIcon = await buildEmojiMarker('📷');
    for (final t in PoiType.values) {
      _poiIcons[t] = await buildEmojiMarker(t.emoji);
    }
    if (mounted) setState(() => _iconsReady = true);
  }

  @override
  void didUpdateWidget(TrackMapWidget old) {
    super.didUpdateWidget(old);
    final c = _mapController;
    if (c == null) return;
    if (widget.followUser &&
        widget.currentPosition != null &&
        widget.currentPosition != old.currentPosition) {
      _moveCamera(c, widget.currentPosition!);
    }
    if (widget.followUser && !old.followUser && widget.currentPosition != null) {
      _moveCamera(c, widget.currentPosition!);
    }
  }

  void _moveCamera(YandexMapController c, LatLng pos) {
    c.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: pos.toYandex(),
          zoom: AppConstants.defaultZoom,
        ),
      ),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.3),
    );
  }

  void _fitTrack(YandexMapController c, List<LatLng> pts) {
    if (pts.length < 2) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    c.moveCamera(
      CameraUpdate.newBounds(BoundingBox(
        southWest: LatLng(minLat, minLng).toYandex(),
        northEast: LatLng(maxLat, maxLng).toYandex(),
      )),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final points = widget.session.points.map((p) => p.position).toList();
    final poisAsync = ref.watch(poisProvider);

    final mapObjects = <MapObject>[
      // Трек — отображается сразу, не требует иконок
      if (points.length > 1)
        PolylineMapObject(
          mapId: const MapObjectId('track'),
          polyline: Polyline(points: points.map((p) => p.toYandex()).toList()),
          strokeColor: colorScheme.primary,
          strokeWidth: 4.0,
          outlineColor: colorScheme.primary.withOpacity(0.3),
          outlineWidth: 1.5,
        ),

      // Точечные маркеры — после загрузки bitmap
      if (_iconsReady) ...[
        if (points.isNotEmpty)
          PlacemarkMapObject(
            mapId: const MapObjectId('start'),
            point: points.first.toYandex(),
            icon: PlacemarkIcon.single(
              PlacemarkIconStyle(image: _startIcon!, scale: 0.7),
            ),
          ),

        if (widget.currentPosition != null)
          PlacemarkMapObject(
            mapId: const MapObjectId('current_pos'),
            point: widget.currentPosition!.toYandex(),
            icon: PlacemarkIcon.single(
              PlacemarkIconStyle(image: _currentPosIcon!, scale: 0.8),
            ),
          ),

        // POI-слой — всегда виден на карте
        ...poisAsync.whenOrNull(
              data: (pois) => pois
                  .map((poi) => PlacemarkMapObject(
                        mapId: MapObjectId('poi_${poi.id}'),
                        point: poi.position.toYandex(),
                        icon: PlacemarkIcon.single(PlacemarkIconStyle(
                          image: _poiIcons[poi.type]!,
                          scale: 0.8,
                        )),
                        onTap: (_, __) => _showPoiSnack(context, poi),
                      ))
                  .toList(),
            ) ??
            [],

        // Фото-маркеры
        ...widget.session.photos.map(
          (photo) => PlacemarkMapObject(
            mapId: MapObjectId('photo_${photo.filePath.hashCode}'),
            point: photo.position.toYandex(),
            icon: PlacemarkIcon.single(
              PlacemarkIconStyle(image: _cameraIcon!, scale: 0.8),
            ),
            onTap: (_, __) {
              widget.onMarkerTap?.call(photo);
              _showPhotoPreview(context, photo);
            },
          ),
        ),
      ],
    ];

    return AbsorbPointer(
      absorbing: !widget.interactive,
      child: YandexMap(
        nightModeEnabled: isDark,
        mapType: MapType.map,
        onMapCreated: (c) {
          _mapController = c;
          widget.onMapReady?.call();
          if (points.length > 1) {
            _fitTrack(c, points);
          } else if (widget.currentPosition != null) {
            _moveCamera(c, widget.currentPosition!);
          }
        },
        mapObjects: mapObjects,
        onCameraPositionChanged: (_, reason, __) {
          if (reason == CameraUpdateReason.gestures) {
            widget.onManualPan?.call();
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
