import 'package:isar/isar.dart';

import 'photo_embed.dart';
import 'track_point_embed.dart';

part 'track_model.g.dart';

/// Isar-коллекция трека.
/// Треки — эфемерный слой (можно скрывать/фильтровать по дате).
@collection
class TrackModel {
  Id id = Isar.autoIncrement;

  /// UUID-строка — стабильный публичный идентификатор трека.
  @Index(unique: true)
  late String uuid;

  late String title;

  @Index()
  late DateTime startedAt;

  DateTime? finishedAt;

  /// ActivityType.index — сериализуем enum как int для гибкости.
  late int activityTypeIndex;

  double distanceMeters = 0;
  int pausedDurationMs = 0;

  List<TrackPointEmbed> points = [];
  List<PhotoEmbed> photos = [];
}
