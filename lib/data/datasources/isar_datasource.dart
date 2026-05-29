import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/isar/poi_model.dart';
import '../models/isar/track_model.dart';

/// Синглтон для доступа к Isar.
/// Инициализируется один раз в main() через [init].
class IsarDatasource {
  IsarDatasource._();
  static final IsarDatasource instance = IsarDatasource._();

  late final Isar _db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _db = await Isar.open(
      [TrackModelSchema, PoiModelSchema],
      directory: dir.path,
      name: 'sled_db',
    );
  }

  Isar get db => _db;
}
