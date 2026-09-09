import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/core/time/time_utils.dart';

void main() {
  test(
    'wallClockToUtc preserves captured offset instead of device timezone',
    () {
      final wall = DateTime(2026, 9, 1, 8, 30);
      expect(wallClockToUtc(wall, -180), DateTime.utc(2026, 9, 1, 11, 30));
      expect(wallClockToUtc(wall, 120), DateTime.utc(2026, 9, 1, 6, 30));
    },
  );
}
