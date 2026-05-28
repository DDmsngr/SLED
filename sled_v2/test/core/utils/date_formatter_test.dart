import 'package:flutter_test/flutter_test.dart';
import 'package:gps_photo_tracker/core/utils/date_formatter.dart';

void main() {
  group('formatDuration', () {
    test('нули', () {
      expect(formatDuration(Duration.zero), '00:00:00');
    });

    test('1 час 2 минуты 3 секунды', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
    });
  });

  group('formatDistance', () {
    test('меньше 1 км', () {
      expect(formatDistance(450), '450 м');
    });

    test('больше 1 км', () {
      expect(formatDistance(1500), '1.50 км');
    });
  });
}
