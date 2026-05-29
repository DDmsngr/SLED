import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track_session.dart';
import 'tracking_provider.dart';

/// Реактивный список сессий из Isar.
/// Автоматически обновляется при изменениях в БД — ref.invalidate больше не нужен.
final sessionsProvider = StreamProvider<List<TrackSession>>((ref) {
  return ref.watch(sessionRepositoryProvider).watchSessions();
});

/// Одна сессия по id.
final sessionByIdProvider =
    FutureProvider.family<TrackSession?, String>((ref, id) async {
  return ref.watch(sessionRepositoryProvider).loadSession(id);
});
