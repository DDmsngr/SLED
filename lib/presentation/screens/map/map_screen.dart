import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/tile_providers/offline_cached_tile_provider.dart';
import '../../../domain/entities/poi.dart';
import '../../../domain/entities/poi_type.dart';
import '../../providers/map_filter_provider.dart';
import '../../providers/poi_provider.dart';

/// Экран «Разведка» (MapMode.scout).
///
/// Трек не пишется. Работает:
/// - отображение текущей позиции пользователя
/// - слой всех POI поверх карты
/// - кнопка «Пынь» — добавить POI в текущую геопозицию
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapCtrl = MapController();
  LatLng? _currentPos;
  bool _followUser = true;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _startPositionWatch();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  void _startPositionWatch() {
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentPos = ll);
      if (_followUser) {
        _mapCtrl.move(ll, _mapCtrl.camera.zoom);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final poisAsync = ref.watch(poisProvider);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Разведка',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          // Кнопка «скрыть/показать треки» — через map filter
          Consumer(builder: (_, ref, __) {
            final filter = ref.watch(mapFilterProvider);
            return IconButton(
              icon: Icon(
                filter.tracksHidden
                    ? Icons.layers_clear
                    : Icons.layers,
                color: Colors.white,
              ),
              tooltip: filter.tracksHidden
                  ? 'Показать треки'
                  : 'Скрыть треки',
              onPressed: filter.tracksHidden
                  ? ref.read(mapFilterProvider.notifier).showAllTracks
                  : ref.read(mapFilterProvider.notifier).hideAllTracks,
            );
          }),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _currentPos ?? const LatLng(59.9500, 30.3167),
              initialZoom: AppConstants.defaultZoom,
              onMapEvent: (event) {
                if (event is MapEventMoveStart &&
                    event.source != MapEventSource.mapController) {
                  setState(() => _followUser = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.osmTileUrl,
                tileProvider: OfflineCachedTileProvider(),
                userAgentPackageName: 'com.example.sled',
                tileBuilder: _darkModeTileBuilder,
              ),

              // ── Слой POI — виден ВСЕГДА ───────────────────────────────
              poisAsync.when(
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
                data: (pois) => MarkerLayer(
                  markers: pois.map(_buildPoiMarker).toList(),
                ),
              ),

              // ── Маркер текущей позиции ────────────────────────────────
              if (_currentPos != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _currentPos!,
                    width: 24,
                    height: 24,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.4),
                            blurRadius: 8,
                          )
                        ],
                      ),
                    ),
                  ),
                ]),
            ],
          ),

          // ── Кнопка re-center ─────────────────────────────────────────
          if (!_followUser && _currentPos != null)
            Positioned(
              top: 100,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                onPressed: () {
                  setState(() => _followUser = true);
                  _mapCtrl.move(_currentPos!, _mapCtrl.camera.zoom);
                },
                backgroundColor: theme.colorScheme.surface,
                child: Icon(Icons.my_location,
                    color: theme.colorScheme.primary),
              ),
            ),

          // ── Кнопка «Пынь» ────────────────────────────────────────────
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

  Marker _buildPoiMarker(Poi poi) {
    return Marker(
      point: poi.position,
      width: 40,
      height: 40,
      child: Tooltip(
        message: '${poi.type.emoji} ${poi.type.label}'
            '${poi.comment != null ? '\n${poi.comment}' : ''}',
        child: GestureDetector(
          onTap: () => _showPoiDetail(context, poi),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            child: Center(
              child: Text(poi.type.emoji,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Боттом-шит добавления «Пынь» ─────────────────────────────────────────

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
              '${poi.createdAt.day}.${poi.createdAt.month.toString().padLeft(2, '0')}'
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

  Widget _darkModeTileBuilder(
      BuildContext ctx, Widget tile, TileImage tileImage) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    if (!isDark) return tile;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -1, 0, 0, 0, 255,
         0,-1, 0, 0, 255,
         0, 0,-1, 0, 255,
         0, 0, 0, 1,   0,
      ]),
      child: tile,
    );
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

          // Тип POI
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PoiType.values.map((t) {
              final sel = _type == t;
              return FilterChip(
                label: Text('${t.emoji} ${t.label}'),
                selected: sel,
                onSelected: (_) => setState(() => _type = t),
              );
            }).toList(),
          ),
          const Gap(16),

          // Комментарий
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(
              labelText: 'Комментарий (необязательно)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const Gap(12),

          // Фото
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
