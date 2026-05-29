import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track_session.dart';

/// Состояние календарного фильтра треков.
class MapFilterState {
  const MapFilterState({
    this.selectedDate,
    this.rangeStart,
    this.rangeEnd,
    this.tracksHidden = false,
  });

  /// Конкретная дата фильтра (исключает диапазон).
  final DateTime? selectedDate;

  /// Начало диапазона дат (исключает selectedDate).
  final DateTime? rangeStart;

  /// Конец диапазона дат.
  final DateTime? rangeEnd;

  /// Если true — все треки скрыты, POI остаются видимыми.
  final bool tracksHidden;

  bool get hasFilter =>
      tracksHidden ||
      selectedDate != null ||
      (rangeStart != null && rangeEnd != null);

  /// Возвращает true, если трек должен отображаться согласно фильтру.
  bool showTrack(TrackSession session) {
    if (tracksHidden) return false;

    if (selectedDate != null) {
      return DateUtils.isSameDay(session.startedAt, selectedDate);
    }

    if (rangeStart != null && rangeEnd != null) {
      final d = DateUtils.dateOnly(session.startedAt);
      return !d.isBefore(DateUtils.dateOnly(rangeStart!)) &&
          !d.isAfter(DateUtils.dateOnly(rangeEnd!));
    }

    return true; // нет активного фильтра — показываем всё
  }

  MapFilterState copyWith({
    DateTime? selectedDate,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    bool? tracksHidden,
    bool clearSelectedDate = false,
    bool clearRange = false,
  }) =>
      MapFilterState(
        selectedDate: clearSelectedDate ? null : (selectedDate ?? this.selectedDate),
        rangeStart:   clearRange        ? null : (rangeStart   ?? this.rangeStart),
        rangeEnd:     clearRange        ? null : (rangeEnd     ?? this.rangeEnd),
        tracksHidden: tracksHidden ?? this.tracksHidden,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class MapFilterNotifier extends StateNotifier<MapFilterState> {
  MapFilterNotifier() : super(const MapFilterState());

  /// Показать треки только за конкретную дату.
  void filterByDate(DateTime date) {
    state = state.copyWith(
      selectedDate: date,
      clearRange: true,
      tracksHidden: false,
    );
  }

  /// Показать треки за диапазон дат.
  void filterByRange(DateTime start, DateTime end) {
    state = state.copyWith(
      rangeStart: start,
      rangeEnd: end,
      clearSelectedDate: true,
      tracksHidden: false,
    );
  }

  /// Убрать все фильтры — показать все треки.
  void clearFilter() => state = const MapFilterState();

  /// Скрыть все треки (POI остаются).
  void hideAllTracks() =>
      state = const MapFilterState(tracksHidden: true);

  /// Показать все треки (сбрасывает скрытие, сохраняет датовый фильтр).
  void showAllTracks() =>
      state = state.copyWith(tracksHidden: false);
}

final mapFilterProvider =
    StateNotifierProvider<MapFilterNotifier, MapFilterState>(
  (_) => MapFilterNotifier(),
);
