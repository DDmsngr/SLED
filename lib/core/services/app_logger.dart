import 'dart:async';

import 'package:flutter/foundation.dart';

class LogEntry {
  final DateTime timestamp;
  final String tag;
  final String message;

  LogEntry(this.tag, this.message) : timestamp = DateTime.now();

  String get timeStr {
    final t = timestamp;
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }
}

/// In-memory log accumulator. Not persisted — resets on app restart.
class AppLogger {
  AppLogger._();

  static final List<LogEntry> _entries = [];
  static final _ctrl = StreamController<List<LogEntry>>.broadcast();

  static List<LogEntry> get entries => List.unmodifiable(_entries);
  static Stream<List<LogEntry>> get stream => _ctrl.stream;

  static void log(String tag, String message) {
    debugPrint('[$tag] $message');
    _entries.insert(0, LogEntry(tag, message));
    if (_entries.length > 300) _entries.removeLast();
    _ctrl.add(entries);
  }

  static void clear() {
    _entries.clear();
    _ctrl.add([]);
  }
}
