import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/features/month_close/domain/workday_fill.dart';
import 'package:oktaponto/features/punch/domain/models.dart';
import 'package:oktaponto/features/schedule/domain/work_schedule.dart';

WorkDaySummary _day(
  int day, {
  List<Punch> punches = const [],
  bool include = true,
}) => WorkDaySummary(
  date: DateTime(2026, 9, day),
  punches: punches,
  status: punches.isEmpty ? WorkDayStatus.empty : WorkDayStatus.open,
  workedMinutes: 0,
  includeInTimesheet: include,
  activity: null,
  issues: const [],
);

Punch _punch(int day) => Punch(
  id: day,
  occurredAtUtc: DateTime.utc(2026, 9, day, 9),
  localDate: '2026-09-${day.toString().padLeft(2, '0')}',
  utcOffsetMinutes: 0,
  kind: PunchKind.in_,
  isEdited: false,
);

void main() {
  test('default pattern keeps eight worked hours and the standard lunch', () {
    final pattern = WorkdayFillPattern.fromSchedule(null);

    expect(pattern.workedMinutes, 480);
    expect(pattern.timesFor(DateTime(2026, 9, 1)), [
      DateTime(2026, 9, 1, 9),
      DateTime(2026, 9, 1, 12),
      DateTime(2026, 9, 1, 13),
      DateTime(2026, 9, 1, 18),
    ]);
  });

  test('only includes empty scheduled weekdays before today', () {
    final month = MonthSummary(
      year: 2026,
      month: 9,
      days: [
        _day(1, punches: [_punch(1)]),
        _day(2, punches: [_punch(2)]), // Dia parcial não é sobrescrito.
        _day(3, include: false), // Exclusão manual permanece respeitada.
        _day(10), // Hoje ainda pode receber batidas reais.
      ],
    );

    final missing = missingScheduledWorkdays(
      month: month,
      schedule: WorkSchedule.defaults,
      now: DateTime(2026, 9, 10, 18),
    );

    expect(missing, [
      DateTime(2026, 9, 4),
      DateTime(2026, 9, 7),
      DateTime(2026, 9, 8),
      DateTime(2026, 9, 9),
    ]);
  });

  test('rejects a pattern that would place the final punch on another day', () {
    final pattern = const WorkdayFillPattern(
      startMinuteOfDay: 20 * 60,
      breakStartMinuteOfDay: 21 * 60,
      breakMinutes: 60,
    );

    expect(pattern.isValid, isFalse);
    expect(() => pattern.timesFor(DateTime(2026, 9, 1)), throwsStateError);
  });
}
