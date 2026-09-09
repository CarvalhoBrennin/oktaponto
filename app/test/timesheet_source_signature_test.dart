import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/features/punch/domain/models.dart';
import 'package:horafolio/features/timesheet/domain/timesheet_source_signature.dart';

WorkDaySummary _day({String? activity, int minute = 0}) => WorkDaySummary(
  date: DateTime(2026, 9, 1),
  punches: [
    Punch(
      id: 1,
      occurredAtUtc: DateTime.utc(2026, 9, 1, 8, minute),
      localDate: '2026-09-01',
      utcOffsetMinutes: 0,
      kind: PunchKind.in_,
      isEdited: false,
    ),
    Punch(
      id: 2,
      occurredAtUtc: DateTime.utc(2026, 9, 1, 12),
      localDate: '2026-09-01',
      utcOffsetMinutes: 0,
      kind: PunchKind.out,
      isEdited: false,
    ),
    Punch(
      id: 3,
      occurredAtUtc: DateTime.utc(2026, 9, 1, 13),
      localDate: '2026-09-01',
      utcOffsetMinutes: 0,
      kind: PunchKind.in_,
      isEdited: false,
    ),
    Punch(
      id: 4,
      occurredAtUtc: DateTime.utc(2026, 9, 1, 17),
      localDate: '2026-09-01',
      utcOffsetMinutes: 0,
      kind: PunchKind.out,
      isEdited: false,
    ),
  ],
  status: WorkDayStatus.complete,
  workedMinutes: 480 - minute,
  includeInTimesheet: true,
  activity: activity,
  issues: const [],
);

void main() {
  const profile = ProfileSettingsModel(
    employeeName: 'A',
    jobTitle: 'B',
    workMode: 'C',
    defaultActivity: 'D',
  );
  test('signature changes when punch or activity changes', () {
    final base = timesheetSourceSignature(
      MonthSummary(year: 2026, month: 9, days: [_day()]),
      profile,
    );
    final punchChanged = timesheetSourceSignature(
      MonthSummary(year: 2026, month: 9, days: [_day(minute: 1)]),
      profile,
    );
    final activityChanged = timesheetSourceSignature(
      MonthSummary(year: 2026, month: 9, days: [_day(activity: 'Outra')]),
      profile,
    );
    expect(punchChanged, isNot(base));
    expect(activityChanged, isNot(base));
  });

  test('signature changes when profile changes', () {
    final month = MonthSummary(year: 2026, month: 9, days: [_day()]);
    final base = timesheetSourceSignature(month, profile);
    final changed = timesheetSourceSignature(
      month,
      profile.copyWith(jobTitle: 'Outro'),
    );
    expect(changed, isNot(base));
  });
}
