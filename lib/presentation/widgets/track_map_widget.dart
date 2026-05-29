import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/tile_providers/offline_cached_tile_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/photo_marker.dart';
import '../../domain/entities/poi.dart';
import '../../domain/entities/track_session.dart';
import '../providers/poi_provider.dart';
import 'photo_marker_widget.dart';

class TrackMapWidget extends ConsumerStatefulWidget {
  const TrackMapWidget({
    super.key,
    required this.session,
    this.currentPosition,
    this.onMarkerTap,
    this.interactive = true,
    this.followUser = false,
    this.onManualPan,
    this.onMapReady,   // новый callback
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
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(TrackMapWidget old) {
    super.didUpdateWidget(old);
    if (widget.followUser &&
        widget.currentPosition != null &&
        widget.currentPosition != old.currentPosition) {
      _mapController.move(widget.currentPosition!, _mapController.camera.zoom);
    }
    if (widget.followUser && !old.followUser && widget.currentPosition != null) {
      _mapController.move(widget.currentPosition!, _mapController.camera.zoom);
    }
  }

  LatLngBounds? _trackBounds() {
    final pts = widget.session.points;
    if (pts.length < 2) return null;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in pts) {
      if (p.position.latitude < minLat) minLat = p.position.latitude;
      if (p.position.latitude > maxLat) maxLat = p.position.latitude;
      if (p.position.longitude < minLng) minLng = p.position.longitude;
      if (p.position.longitude > maxLng) maxLng = p.position.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final points = widget.session.points.map((p) => p.position).toList();
    final bounds = _trackBounds();
    final center = widget.currentPosition ??
        (points.isNotEmpty ? points.last : const LatLng(55.751244, 37.618423));

    final poisAsync = ref.watch(poisProvider);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: AppConstants.defaultZoom,
        initialCameraFit: bounds != null
            ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40))
            : null,
        interactionOptions: InteractionOptions(
          flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onMapReady: () => widget.onMapReady?.call(),
        onMapEvent: (event) {
          if (event is MapEventMoveStart &&
              event.source != MapEventSource.mapController) {
            widget.onManualPan?.call();
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: AppConstants.osmTileUrl,
          tileProvider: const OfflineCachedTileProvider(),
          userAgentPackageName: 'com.example.sled',
          tileBuilder: (context, tileWidget, tile) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            if (!isDark) return tileWidget;
            return ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                -1, 0, 0, 0, 255,
                 0,-1, 0, 0, 255,
                 0, 0,-1, 0, 255,
                 0, 0, 0, 1,   0,
              ]),
              child: tileWidget,
            );
          },
        ),

        // ── POI-слой — ОБЯЗАТЕЛЬНО виден в режиме «Запись следа» ─────────
        poisAsync.when(
          loading: () => const MarkerLayer(markers: []),
          error: (_, __) => const MarkerLayer(markers: []),
          data: (pois) => MarkerLayer(
            markers: pois.map(_buildPoiMarker).toList(),
          ),
        ),

        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4.0,
                color: colorScheme.primary,
                borderStrokeWidth: 1.5,
                borderColor: colorScheme.primary.withOpacity(0.3),
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
          ),

        if (points.isNotEmpty)
          MarkerLayer(markers: [
            Marker(
              point: points.first, width: 20, height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ]),

        if (widget.currentPosition != null)
          MarkerLayer(markers: [
            Marker(
              point: widget.currentPosition!, width: 24, height: 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4), blurRadius: 8)],
                ),
              ),
            ),
          ]),

        MarkerLayer(
          markers: widget.session.photos.map((photo) {
            return Marker(
              point: photo.position, width: 52, height: 52,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: () {
                    widget.onMarkerTap?.call(photo);
                    _showPhotoPreview(context, photo);
                  },
                  child: PhotoMarkerWidget(photo: photo),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Marker _buildPoiMarker(Poi poi) {
    return Marker(
      point: poi.position,
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => _showPoiInfo(context, poi),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Center(
            child: Text(poi.type.emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  void _showPoiInfo(BuildContext context, Poi poi) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${poi.type.emoji} ${poi.type.label}'
            '${poi.comment != null ? ': ${poi.comment}' : ''}'),
        duration: const Duration(seconds: 2),
      ),
    );
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
              child: Image.file(File(photo.filePath),
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image, color: Colors.white, size: 64)),
            ),
            Positioned(top: 8, right: 8,
                child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context))),
            Positioned(bottom: 8, left: 0, right: 0,
                child: Center(
                    child: Text(formatDateTime(photo.timestamp),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)))),
          ],
        ),
      ),
    );
  }
}
