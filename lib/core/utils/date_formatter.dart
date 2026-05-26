import 'package:intl/intl.dart';

/// Duration → «чч:мм:сс».
String formatDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// DateTime → читаемая строка UI.
String formatDateTime(DateTime dt) =>
    DateFormat('dd.MM.yyyy  HH:mm').format(dt);

/// Метры → «1.23 км» или «450 м».
String formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(2)} км';
  }
  return '${meters.toStringAsFixed(0)} м';
}
