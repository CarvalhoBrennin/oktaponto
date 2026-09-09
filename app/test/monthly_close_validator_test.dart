import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/features/month_close/domain/monthly_close_validator.dart';
import 'package:horafolio/features/punch/domain/models.dart';

Punch _p(int id, int hour, int minute, PunchKind kind) => Punch(
      id: id,
      occurredAtUtc: DateTime.utc(2026, 9, 1, hour, minute),
      localDate: '2026-09-01',
      utcOffsetMinutes: 0,
      kind: kind,
      isEdited: false,
    );

WorkDaySummary completeDay({bool include = true}) => WorkDaySummary(
      date: DateTime(2026, 9, 1),
      punches: [_p(1, 8, 0, PunchKind.in_), _p(2, 12, 0, PunchKind.out), _p(3, 13, 0, PunchKind.in_), _p(4, 17, 0, PunchKind.out)],
      status: WorkDayStatus.complete,
      workedMinutes: 480,
      includeInTimesheet: include,
      activity: null,
      issues: const [],
    );

void main() {
  const validator = DefaultMonthlyCloseValidator();

  test('complete month derived from punches is valid', () {
    expect(
      validator.validate(MonthSummary(year: 2026, month: 9, days: [completeDay()])).isValid,
      isTrue,
    );
  });

  test('forged derived totals are rejected fail-closed', () {
    final source = completeDay();
    final forged = WorkDaySummary(
      date: source.date,
      punches: source.punches,
      status: WorkDayStatus.complete,
      workedMinutes: 999,
      includeInTimesheet: true,
      activity: null,
      issues: const [],
    );
    final result = validator.validate(MonthSummary(year: 2026, month: 9, days: [forged]));
    expect(result.issues.any((i) => i.code.startsWith('derived_mismatch_')), isTrue);
  });

  test('incomplete day blocks close', () {
    final day = WorkDaySummary(
      date: DateTime(2026, 9, 1),
      punches: [_p(1, 8, 0, PunchKind.in_)],
      status: WorkDayStatus.open,
      workedMinutes: 0,
      includeInTimesheet: true,
      activity: null,
      issues: const [],
    );
    expect(validator.validate(MonthSummary(year: 2026, month: 9, days: [day])).isValid, isFalse);
  });

  test('duplicate date blocks close', () {
    final result = validator.validate(MonthSummary(year: 2026, month: 9, days: [completeDay(), completeDay()]));
    expect(result.issues.any((i) => i.code.startsWith('duplicate_date_')), isTrue);
  });

  test('excluded incomplete day does not block if another included day exists', () {
    final excluded = WorkDaySummary(
      date: DateTime(2026, 9, 2),
      punches: const [],
      status: WorkDayStatus.empty,
      workedMinutes: 0,
      includeInTimesheet: false,
      activity: null,
      issues: const [],
    );
    final result = validator.validate(MonthSummary(year: 2026, month: 9, days: [completeDay(), excluded]));
    expect(result.isValid, isTrue);
  });
}
