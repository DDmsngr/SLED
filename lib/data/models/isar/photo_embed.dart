import 'package:isar/isar.dart';

part 'photo_embed.g.dart';

/// Embedded-объект: фото-маркер с геопозицией внутри TrackModel.
@embedded
class PhotoEmbed {
  String markerId = '';
  String path = '';
  double lat = 0;
  double lng = 0;
  int timestampMs = 0;
}
