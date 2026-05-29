import 'package:isar/isar.dart';

part 'track_point_embed.g.dart';

/// Embedded-объект: одна GPS-точка внутри TrackModel.
/// Isar требует поля с дефолтными значениями (не late) для embedded.
@embedded
class TrackPointEmbed {
  double lat = 0;
  double lng = 0;
  int timestampMs = 0;
  double speedMs = 0;
  double accuracyM = 0;
  double altitudeM = 0;
}
