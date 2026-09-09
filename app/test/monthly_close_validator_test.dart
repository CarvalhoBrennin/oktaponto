import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/features/month_close/domain/monthly_close_validator.dart';
import 'package:horafolio/features/punch/domain/models.dart';

WorkDaySummary day(int day, {WorkDayStatus status = WorkDayStatus.complete, int minutes = 480, bool include = true}) => WorkDaySummary(
      date: DateTime(2026, 9, day),
      punches: const [],
      status: status,
      workedMinutes: minutes,
      includeInTimesheet: include,
      activity: null,
      issues: const [],
    );

void main() {
  const validator = DefaultMonthlyCloseValidator();
  test('complete month is valid', () {
    expect(validator.validate(MonthSummary(year: 2026, month: 9, days: [day(1)])).isValid, isTrue);
  });
  test('3-punch/open day blocks close', () {
    final result = validator.validate(MonthSummary(year: 2026, month: 9, days: [day(1, status: WorkDayStatus.open, minutes: 240)]));
    expect(result.isValid, isFalse);
  });
  test('over 24h blocks close', () {
    final result = validator.validate(MonthSummary(year: 2026, month: 9, days: [day(1, minutes: 1441)]));
    expect(result.isValid, isFalse);
  });
  test('duplicate date blocks close', () {
    final result = validator.validate(MonthSummary(year: 2026, month: 9, days: [day(1), day(1)]));
    expect(result.issues.any((i) => i.code.startsWith('duplicate_date_')), isTrue);
  });
  test('excluded incomplete day does not block if another included day exists', () {
    final result = validator.validate(MonthSummary(year: 2026, month: 9, days: [day(1), day(2, status: WorkDayStatus.open, include: false)]));
    expect(result.isValid, isTrue);
  });
}
