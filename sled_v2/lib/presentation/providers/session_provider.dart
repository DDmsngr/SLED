import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track_session.dart';
import 'tracking_provider.dart';

/// Список всех сохранённых сессий.
final sessionsProvider = FutureProvider<List<TrackSession>>((ref) async {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.loadSessions();
});

/// Одна сессия по id.
final sessionByIdProvider =
    FutureProvider.family<TrackSession?, String>((ref, id) async {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.loadSession(id);
});
