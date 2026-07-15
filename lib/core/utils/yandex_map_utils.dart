import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:yandex_maps_mapkit/image.dart' as ymk_image;
import 'package:yandex_maps_mapkit/mapkit.dart' as ymk;

// ── LatLng ⇄ Yandex Point ────────────────────────────────────────────────────

extension LatLngExt on LatLng {
  ymk.Point toYandex() => ymk.Point(latitude: latitude, longitude: longitude);
}

extension YandexPointExt on ymk.Point {
  LatLng toLatLng() => LatLng(latitude, longitude);
}

// ── Bitmap cache: key → ImageProvider ────────────────────────────────────────
// Кэшируем сгенерированные PNG-байты и обёрнутые в ImageProvider, чтобы не
// перерисовывать одну и ту же иконку каждый раз при обновлении карты.
final Map<String, Uint8List> _bytesCache = {};

Future<ymk_image.ImageProvider> buildCircleMarker(
  Color color, {
  double size = 48,
}) async {
  final key = 'circle_${color.toARGB32().toRadixString(16)}_$size';
  final bytes = _bytesCache[key] ??= await _renderCircle(color, size);
  return ymk_image.ImageProvider.fromImageProvider(
    MemoryImage(bytes),
    id: key,
  );
}

Future<ymk_image.ImageProvider> buildEmojiMarker(String emoji,
    {double size = 48}) async {
  final key = 'emoji_${emoji}_$size';
  final bytes = _bytesCache[key] ??= await _renderEmojiCircle(emoji, size);
  return ymk_image.ImageProvider.fromImageProvider(
    MemoryImage(bytes),
    id: key,
  );
}

// ── Rendering ─────────────────────────────────────────────────────────────────

Future<Uint8List> _renderCircle(Color color, double size) async {
  final r = size / 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Drop shadow
  canvas.drawCircle(
    Offset(r, r + 1.5),
    r - 2,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  // White ring
  canvas.drawCircle(Offset(r, r), r - 1, Paint()..color = Colors.white);
  // Color fill
  canvas.drawCircle(Offset(r, r), r - 4, Paint()..color = color);

  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<Uint8List> _renderEmojiCircle(String emoji, double size) async {
  final r = size / 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Drop shadow
  canvas.drawCircle(
    Offset(r, r + 1),
    r - 1,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  // White circle
  canvas.drawCircle(Offset(r, r), r - 1, Paint()..color = Colors.white);
  // Thin border
  canvas.drawCircle(
    Offset(r, r),
    r - 1,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );

  // Emoji text via dart:ui ParagraphBuilder (no widget tree needed)
  final paragraph = (ui.ParagraphBuilder(
    ui.ParagraphStyle(
      fontSize: size * 0.5,
      textAlign: TextAlign.center,
    ),
  )..addText(emoji))
      .build()
    ..layout(ui.ParagraphConstraints(width: size));

  canvas.drawParagraph(
    paragraph,
    Offset(0, (size - paragraph.height) / 2),
  );

  final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
