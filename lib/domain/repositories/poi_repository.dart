import '../entities/poi.dart';

abstract interface class PoiRepository {
  /// Живой поток всех POI — реагирует на добавление/удаление без invalidate.
  Stream<List<Poi>> watchAllPois();

  Future<List<Poi>> getAllPois();
  Future<void> savePoi(Poi poi);
  Future<void> deletePoi(String id);
}
