import 'package:isar/isar.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/activity_type.dart';
import '../../domain/entities/photo_marker.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/entities/track_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../datasources/isar_datasource.dart';
import '../models/isar/photo_embed.dart';
import '../models/isar/track_model.dart';
import '../models/isar/track_point_embed.dart';

class IsarSessionRepositoryImpl implements SessionRepository {
  IsarSessionRepositoryImpl(this._ds);

  final IsarDatasource _ds;
  Isar get _db => _ds.db;

  // ── Живой поток ──────────────────────────────────────────────────────────

  @override
  Stream<List<TrackSession>> watchSessions() {
    return _db.trackModels
        .where()
        .sortByStartedAtDesc()
        .watch(fireImmediately: true)
        .map((list) => list.map(_toDomain).toList());
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  @override
  Future<List<TrackSession>> loadSessions() async {
    final models = await _db.trackModels
        .where()
        .sortByStartedAtDesc()
        .findAll();
    return models.map(_toDomain).toList();
  }

  @override
  Future<TrackSession?> loadSession(String id) async {
    final model = await _db.trackModels
        .where()
        .uuidEqualTo(id)
        .findFirst();
    return model == null ? null : _toDomain(model);
  }

  // ── Мутации ───────────────────────────────────────────────────────────────

  @override
  Future<void> saveSession(TrackSession session) async {
    final model = _fromDomain(session);
    // Isar по умолчанию auto-increment, но нам нужно обновить существующую
    // запись: ищем по uuid и переиспользуем её isarId.
    final existing = await _db.trackModels
        .where()
        .uuidEqualTo(session.id)
        .findFirst();
    if (existing != null) model.id = existing.id;

    await _db.writeTxn(() => _db.trackModels.put(model));
  }

  @override
  Future<void> deleteSession(String id) async {
    await _db.writeTxn(() async {
      final model = await _db.trackModels
          .where()
          .uuidEqualTo(id)
          .findFirst();
      if (model != null) await _db.trackModels.delete(model.id);
    });
  }

  @override
  Future<void> addPhotoMarker(String sessionId, PhotoMarker marker) async {
    final model = await _db.trackModels
        .where()
        .uuidEqualTo(sessionId)
        .findFirst();
    if (model == null) return;

    // Isar возвращает embed-list как fixed-length, .add() на нём кидает
    // 'Cannot add to a fixed-length list'. Пересобираем список.
    model.photos = [
      ...model.photos,
      PhotoEmbed()
        ..markerId = marker.id
        ..path = marker.filePath
        ..lat = marker.position.latitude
        ..lng = marker.position.longitude
        ..timestampMs = marker.timestamp.millisecondsSinceEpoch,
    ];

    await _db.writeTxn(() => _db.trackModels.put(model));
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  TrackSession _toDomain(TrackModel m) => TrackSession(
        id: m.uuid,
        title: m.title,
        startedAt: m.startedAt,
        finishedAt: m.finishedAt,
        activityType: ActivityType.values[m.activityTypeIndex],
        distanceMeters: m.distanceMeters,
        pausedDurationMs: m.pausedDurationMs,
        points: m.points.map(_pointToDomain).toList(),
        photos: m.photos.map(_photoToDomain).toList(),
      );

  TrackPoint _pointToDomain(TrackPointEmbed e) => TrackPoint(
        position: LatLng(e.lat, e.lng),
        timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestampMs),
        speedMs: e.speedMs,
        accuracyM: e.accuracyM,
        altitudeM: e.altitudeM,
      );

  PhotoMarker _photoToDomain(PhotoEmbed e) => PhotoMarker(
        id: e.markerId,
        filePath: e.path,
        position: LatLng(e.lat, e.lng),
        timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestampMs),
      );

  TrackModel _fromDomain(TrackSession s) {
    final m = TrackModel()
      ..uuid = s.id
      ..title = s.title
      ..startedAt = s.startedAt
      ..finishedAt = s.finishedAt
      ..activityTypeIndex = s.activityType.index
      ..distanceMeters = s.distanceMeters
      ..pausedDurationMs = s.pausedDurationMs
      ..points = s.points.map(_pointFromDomain).toList()
      ..photos = s.photos.map(_photoFromDomain).toList();
    return m;
  }

  TrackPointEmbed _pointFromDomain(TrackPoint p) => TrackPointEmbed()
    ..lat = p.position.latitude
    ..lng = p.position.longitude
    ..timestampMs = p.timestamp.millisecondsSinceEpoch
    ..speedMs = p.speedMs
    ..accuracyM = p.accuracyM
    ..altitudeM = p.altitudeM;

  PhotoEmbed _photoFromDomain(PhotoMarker m) => PhotoEmbed()
    ..markerId = m.id
    ..path = m.filePath
    ..lat = m.position.latitude
    ..lng = m.position.longitude
    ..timestampMs = m.timestamp.millisecondsSinceEpoch;
}
