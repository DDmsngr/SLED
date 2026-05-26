import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_error.dart';
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

      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      state = state.copyWith(progress: 0.8);

      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 95,
        name: 'track_collage_${session.id.substring(0, 8)}',
      );
      state = state.copyWith(
        isExporting: false,
        progress: 1.0,
        lastSavedPath: result['filePath'] as String?,
      );
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        error: 'Ошибка экспорта коллажа: $e',
      );
    }
  }

  Future<String> exportGpx(TrackSession session) async {
    final buf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<gpx version="1.1" creator="GPS Трекер">')
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
    final file = File(p.join(dir.path, 'export_${session.id}.gpx'));
    await file.writeAsString(buf.toString());
    return file.path;
  }

  Future<void> exportVideo(
    TrackSession session,
    List<Uint8List> frames,
  ) async {
    if (frames.isEmpty) {
      state = state.copyWith(error: 'Нет кадров для видео');
      return;
    }
    state = state.copyWith(isExporting: true, progress: 0.05);

    try {
      final tmpDir = await getTemporaryDirectory();
      final framesDir =
          Directory(p.join(tmpDir.path, 'video_frames_${session.id}'));
      await framesDir.create(recursive: true);

      for (int i = 0; i < frames.length; i++) {
        final file = File(p.join(
            framesDir.path, 'frame_${i.toString().padLeft(4, '0')}.png'));
        await file.writeAsBytes(frames[i]);
        state = state.copyWith(progress: 0.05 + 0.5 * (i / frames.length));
      }

      final outputPath =
          p.join(tmpDir.path, 'track_${session.id.substring(0, 8)}.mp4');

      final cmd = '-y -framerate ${AppConstants.videoFps} '
          '-i ${framesDir.path}/frame_%04d.png '
          '-c:v libx264 -b:v ${AppConstants.videoBitrate} '
          '-vf scale=1080:-2 -pix_fmt yuv420p '
          '$outputPath';

      state = state.copyWith(progress: 0.6);

      final ffSession = await FFmpegKit.execute(cmd);
      final rc = await ffSession.getReturnCode();

      if (!ReturnCode.isSuccess(rc)) {
        final logs = await ffSession.getAllLogsAsString();
        throw ExportError('FFmpeg error:\n$logs');
      }

      state = state.copyWith(progress: 0.9);
      await ImageGallerySaver.saveFile(outputPath);
      await framesDir.delete(recursive: true);

      state = state.copyWith(
        isExporting: false,
        progress: 1.0,
        lastSavedPath: outputPath,
      );
    } catch (e) {
      state = state.copyWith(isExporting: false, error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final exportProvider =
    StateNotifierProvider<ExportNotifier, ExportState>((_) => ExportNotifier());
