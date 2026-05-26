import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/track_session.dart';

class ExportState {
  const ExportState({
    this.isExporting = false,
    this.progress = 0.0,
    this.lastSavedPath,
    this.error,
  });

  final bool isExporting;
  final double progress;
  final String? lastSavedPath;
  final String? error;

  ExportState copyWith({
    bool? isExporting,
    double? progress,
    String? lastSavedPath,
    String? error,
  }) =>
      ExportState(
        isExporting: isExporting ?? this.isExporting,
        progress: progress ?? this.progress,
        lastSavedPath: lastSavedPath ?? this.lastSavedPath,
        error: error,
      );
}

class ExportNotifier extends StateNotifier<ExportState> {
  ExportNotifier() : super(const ExportState());

  Future<void> exportCollage(
    GlobalKey repaintKey,
    TrackSession session,
  ) async {
    state = state.copyWith(isExporting: true, progress: 0.1);
    try {
      final boundary = repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image =
          await boundary.toImage(pixelRatio: AppConstants.collagePixelRatio);
      state = state.copyWith(progress: 0.5);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      state = state.copyWith(progress: 0.75);

      final tmpDir = await getTemporaryDirectory();
      final name = 'sled_${session.id.substring(0, 8)}.png';
      final tmpFile = File(p.join(tmpDir.path, name));
      await tmpFile.writeAsBytes(bytes);

      await Gal.putImage(tmpFile.path, album: 'SLED');
      await tmpFile.delete();

      state = state.copyWith(
        isExporting: false,
        progress: 1.0,
        lastSavedPath: name,
      );
    } catch (e) {
      state = state.copyWith(isExporting: false, error: 'Ошибка экспорта: $e');
    }
  }

  Future<String> exportGpx(TrackSession session) async {
    final buf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<gpx version="1.1" creator="SLED">')
      ..writeln('  <trk><name>${session.title}</name><trkseg>');

    for (final pt in session.points) {
      buf.writeln(
        '    <trkpt lat="${pt.position.latitude}" '
        'lon="${pt.position.longitude}">'
        '<time>${pt.timestamp.toUtc().toIso8601String()}</time>'
        '</trkpt>',
      );
    }
    buf.writeln('  </trkseg></trk></gpx>');

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'sled_${session.id}.gpx'));
    await file.writeAsString(buf.toString());
    return file.path;
  }

  Future<void> shareRoute(TrackSession session) async {
    state = state.copyWith(isExporting: true, progress: 0.3);
    try {
      final path = await exportGpx(session);
      state = state.copyWith(progress: 0.8);
      await Share.shareXFiles(
        [XFile(path)],
        subject: session.title,
        text: '${session.title}\n'
            '${formatDistance(session.distanceMeters)} · '
            '${formatDuration(session.duration)}\n'
            'Записано в SLED',
      );
      state = state.copyWith(isExporting: false, progress: 1.0);
    } catch (e) {
      state = state.copyWith(isExporting: false, error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final exportProvider =
    StateNotifierProvider<ExportNotifier, ExportState>((_) => ExportNotifier());
