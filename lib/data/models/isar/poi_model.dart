import 'package:isar/isar.dart';

part 'poi_model.g.dart';

/// Isar-коллекция точки интереса (POI / «Пынь»).
/// POI — ПОСТОЯННЫЙ личный слой карты: виден всегда, независимо от треков.
@collection
class PoiModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  late double lat;
  late double lng;

  /// PoiType.index
  late int poiTypeIndex;

  String? photoPath; // только фото (без голосовых заметок — требование заказчика)
  String? comment;  // текстовый комментарий

  @Index()
  late DateTime createdAt;
}
