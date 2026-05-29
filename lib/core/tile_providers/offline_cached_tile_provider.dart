import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Двухуровневый tile-провайдер для flutter_map 7.x.
///
/// Уровень 1 — диск: appDir/tiles/{z}/{x}/{y}.png
///   Если тайл есть на диске — отдаёт без сети (истинный offline).
///
/// Уровень 2 — сеть (OSM): скачивает тайл и кэширует на диск.
///   При отсутствии связи молча показывает серый плейсхолдер.
///
/// Для предварительной загрузки региона используй [prefetchRegion].
class OfflineCachedTileProvider extends TileProvider {
  OfflineCachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _TileDiskCacheImage(coords: coordinates);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TileDiskCacheImage extends ImageProvider<_TileDiskCacheImage> {
  const _TileDiskCacheImage({required this.coords});
  final TileCoordinates coords;

  @override
  Future<_TileDiskCacheImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _TileDiskCacheImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _resolve(decode),
      scale: 1.0,
      informationCollector: () => [
        DiagnosticsProperty('tile', '${coords.z}/${coords.x}/${coords.y}'),
      ],
    );
  }

  Future<ui.Codec> _resolve(ImageDecoderCallback decode) async {
    final dir = (await getApplicationDocumentsDirectory()).path;
    final path = p.join(dir, 'tiles',
        '${coords.z}', '${coords.x}', '${coords.y}.png');
    final file = File(path);

    // ── 1. Кэш на диске ──────────────────────────────────────────────────
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    }

    // ── 2. Сеть → кэш ────────────────────────────────────────────────────
    final url =
        'https://tile.openstreetmap.org/${coords.z}/${coords.x}/${coords.y}.png';
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'SLED/1.2 flutter_map (offline-capable)',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await Directory(p.dirname(path)).create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
        return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
      }
    } catch (_) {
      // нет связи или таймаут — показываем плейсхолдер
    }

    // ── 3. Серый плейсхолдер 1×1 ─────────────────────────────────────────
    return decode(await ui.ImmutableBuffer.fromUint8List(_grayPng));
  }

  @override
  bool operator ==(Object other) =>
      other is _TileDiskCacheImage && coords == other.coords;

  @override
  int get hashCode => coords.hashCode;
}

// 1×1 серый PNG (RGB 0xBB) — масштабируется TileLayer до 256×256.
final Uint8List _grayPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR length + type
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // width=1, height=1
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, // 8-bit RGB, CRC
  0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT length + type
  0x08, 0xD7, 0x63, 0xD4, 0xD4, 0xD4, 0x00, 0x00, // zlib: grey #D4D4D4
  0x00, 0x04, 0x00, 0x01, 0x46, 0x6D, 0xA9, 0xE3, // data + CRC
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND
  0xAE, 0x42, 0x60, 0x82,
]);
