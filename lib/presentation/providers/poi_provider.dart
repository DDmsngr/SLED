import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/datasources/isar_datasource.dart';
import '../../data/repositories/poi_repository_impl.dart';
import '../../domain/entities/poi.dart';
import '../../domain/entities/poi_type.dart';
import '../../domain/repositories/poi_repository.dart';

// ── Зависимости ───────────────────────────────────────────────────────────────

final poiRepositoryProvider = Provider<PoiRepository>(
  (_) => PoiRepositoryImpl(IsarDatasource.instance),
);

/// Живой поток всех POI — автоматически обновляется при изменениях в Isar.
/// POI видны ВСЕГДА (оба режима карты), поэтому StreamProvider без TTL.
final poisProvider = StreamProvider<List<Poi>>((ref) {
  return ref.watch(poiRepositoryProvider).watchAllPois();
});

// ── Notifier для добавления «Пынь» ────────────────────────────────────────────

class AddPoiNotifier extends StateNotifier<AsyncValue<void>> {
  AddPoiNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;
  final _uuid = const Uuid();
  final _picker = ImagePicker();

  /// Добавляет POI в текущую геопозицию.
  /// [withPhoto] — открыть камеру и прикрепить фото.
  /// [comment] — текстовый комментарий (необязательно).
  Future<void> addPoi({
    required LatLng position,
    required PoiType type,
    String? comment,
    bool withPhoto = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      String? photoPath;

      if (withPhoto) {
        final xfile = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1920,
        );
        if (xfile != null) {
          final dir = await getApplicationDocumentsDirectory();
          final dest = p.join(dir.path, 'poi_photos', '${_uuid.v4()}.jpg');
          await Directory(p.dirname(dest)).create(recursive: true);
          await File(xfile.path).copy(dest);
          photoPath = dest;
        }
      }

      final poi = Poi(
        id: _uuid.v4(),
        position: position,
        type: type,
        createdAt: DateTime.now(),
        photoPath: photoPath,
        comment: (comment?.trim().isEmpty ?? true) ? null : comment!.trim(),
      );

      await _ref.read(poiRepositoryProvider).savePoi(poi);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deletePoi(String id) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(poiRepositoryProvider).deletePoi(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final addPoiProvider =
    StateNotifierProvider<AddPoiNotifier, AsyncValue<void>>(
  (ref) => AddPoiNotifier(ref),
);
