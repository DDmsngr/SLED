import 'package:isar/isar.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/poi.dart';
import '../../domain/entities/poi_type.dart';
import '../../domain/repositories/poi_repository.dart';
import '../datasources/isar_datasource.dart';
import '../models/isar/poi_model.dart';

class PoiRepositoryImpl implements PoiRepository {
  PoiRepositoryImpl(this._ds);

  final IsarDatasource _ds;
  Isar get _db => _ds.db;

  @override
  Stream<List<Poi>> watchAllPois() {
    return _db.poiModels
        .where()
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true)
        .map((list) => list.map(_toDomain).toList());
  }

  @override
  Future<List<Poi>> getAllPois() async {
    final models = await _db.poiModels.where().findAll();
    return models.map(_toDomain).toList();
  }

  @override
  Future<void> savePoi(Poi poi) async {
    final model = _fromDomain(poi);
    final existing = await _db.poiModels
        .where()
        .uuidEqualTo(poi.id)
        .findFirst();
    if (existing != null) model.id = existing.id;
    await _db.writeTxn(() => _db.poiModels.put(model));
  }

  @override
  Future<void> deletePoi(String id) async {
    await _db.writeTxn(() async {
      final model = await _db.poiModels
          .where()
          .uuidEqualTo(id)
          .findFirst();
      if (model != null) await _db.poiModels.delete(model.id);
    });
  }

  Poi _toDomain(PoiModel m) => Poi(
        id: m.uuid,
        position: LatLng(m.lat, m.lng),
        type: PoiType.values[m.poiTypeIndex],
        createdAt: m.createdAt,
        photoPath: m.photoPath,
        comment: m.comment,
      );

  PoiModel _fromDomain(Poi p) => PoiModel()
    ..uuid = p.id
    ..lat = p.position.latitude
    ..lng = p.position.longitude
    ..poiTypeIndex = p.type.index
    ..createdAt = p.createdAt
    ..photoPath = p.photoPath
    ..comment = p.comment;
}
