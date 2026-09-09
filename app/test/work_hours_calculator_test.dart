import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/features/punch/domain/models.dart';
import 'package:horafolio/features/punch/domain/work_hours_calculator.dart';

Punch p(int id, int hour, int minute, PunchKind kind) => Punch(
  id: id,
  occurredAtUtc: DateTime.utc(2026, 9, 1, hour, minute),
  localDate: '2026-09-01',
  utcOffsetMinutes: 0,
  kind: kind,
  isEdited: false,
);

void main() {
  const calculator = DefaultWorkHoursCalculator();
  const metadata = WorkDayMetadata(localDate: '2026-09-01');

  test('08-12 + 13-17 = 480 minutes', () {
    final summary = calculator.calculate(DateTime(2026, 9, 1), [
      p(1, 8, 0, PunchKind.in_),
      p(2, 12, 0, PunchKind.out),
      p(3, 13, 0, PunchKind.in_),
      p(4, 17, 0, PunchKind.out),
    ], metadata);
    expect(summary.status, WorkDayStatus.complete);
    expect(summary.workedMinutes, 480);
    expect(summary.isEligibleForTimesheet, isTrue);
  });

  test('states for 1, 2 and 3 punches', () {
    expect(
      calculator.calculate(DateTime(2026, 9, 1), [
        p(1, 8, 0, PunchKind.in_),
      ], metadata).status,
      WorkDayStatus.open,
    );
    expect(
      calculator.calculate(DateTime(2026, 9, 1), [
        p(1, 8, 0, PunchKind.in_),
        p(2, 12, 0, PunchKind.out),
      ], metadata).status,
      WorkDayStatus.paused,
    );
    expect(
      calculator.calculate(DateTime(2026, 9, 1), [
        p(1, 8, 0, PunchKind.in_),
        p(2, 12, 0, PunchKind.out),
        p(3, 13, 0, PunchKind.in_),
      ], metadata).status,
      WorkDayStatus.open,
    );
  });

  test('first punch OUT is invalid', () {
    final summary = calculator.calculate(DateTime(2026, 9, 1), [
      p(1, 8, 0, PunchKind.out),
    ], metadata);
    expect(summary.status, WorkDayStatus.invalid);
  });

  test('equal timestamps are invalid', () {
    final summary = calculator.calculate(DateTime(2026, 9, 1), [
      p(1, 8, 0, PunchKind.in_),
      p(2, 8, 0, PunchKind.out),
    ], metadata);
    expect(summary.status, WorkDayStatus.invalid);
  });

  test('more than 24h is invalid', () {
    final punches = [
      Punch(
        id: 1,
        occurredAtUtc: DateTime.utc(2026, 9, 1),
        localDate: '2026-09-01',
        utcOffsetMinutes: 0,
        kind: PunchKind.in_,
        isEdited: false,
      ),
      Punch(
        id: 2,
        occurredAtUtc: DateTime.utc(2026, 9, 2, 1),
        localDate: '2026-09-01',
        utcOffsetMinutes: 0,
        kind: PunchKind.out,
        isEdited: false,
      ),
    ];
    final summary = calculator.calculate(
      DateTime(2026, 9, 1),
      punches,
      metadata,
    );
    expect(summary.status, WorkDayStatus.invalid);
    expect(summary.issues.any((i) => i.code == 'worked_over_24h'), isTrue);
  });

  test(
    'input timestamps out of order fail closed instead of being normalized away',
    () {
      final summary = calculator.calculate(DateTime(2026, 9, 1), [
        p(1, 8, 0, PunchKind.in_),
        p(3, 13, 0, PunchKind.in_),
        p(2, 12, 0, PunchKind.out),
        p(4, 17, 0, PunchKind.out),
      ], metadata);
      expect(summary.status, WorkDayStatus.invalid);
      expect(
        summary.issues.any(
          (i) => i.code == 'timestamps_not_strictly_increasing',
        ),
        isTrue,
      );
    },
  );

  test(
    'timestamp whose reconstructed local day crosses midnight requires manual review',
    () {
      final summary = calculator.calculate(DateTime(2026, 9, 1), [
        Punch(
          id: 1,
          occurredAtUtc: DateTime.utc(2026, 9, 1, 20),
          localDate: '2026-09-01',
          utcOffsetMinutes: 0,
          kind: PunchKind.in_,
          isEdited: false,
        ),
        Punch(
          id: 2,
          occurredAtUtc: DateTime.utc(2026, 9, 1, 23),
          localDate: '2026-09-01',
          utcOffsetMinutes: 0,
          kind: PunchKind.out,
          isEdited: false,
        ),
        Punch(
          id: 3,
          occurredAtUtc: DateTime.utc(2026, 9, 2),
          localDate: '2026-09-01',
          utcOffsetMinutes: 0,
          kind: PunchKind.in_,
          isEdited: true,
        ),
        Punch(
          id: 4,
          occurredAtUtc: DateTime.utc(2026, 9, 2, 2),
          localDate: '2026-09-01',
          utcOffsetMinutes: 0,
          kind: PunchKind.out,
          isEdited: true,
        ),
      ], metadata);
      expect(summary.status, WorkDayStatus.invalid);
      expect(summary.issues.any((i) => i.code == 'cross_local_date'), isTrue);
    },
  );

  test('include=false excludes an otherwise complete day', () {
    final summary = calculator.calculate(
      DateTime(2026, 9, 1),
      [
        p(1, 8, 0, PunchKind.in_),
        p(2, 12, 0, PunchKind.out),
        p(3, 13, 0, PunchKind.in_),
        p(4, 17, 0, PunchKind.out),
      ],
      const WorkDayMetadata(localDate: '2026-09-01', includeInTimesheet: false),
    );
    expect(summary.status, WorkDayStatus.complete);
    expect(summary.isEligibleForTimesheet, isFalse);
  });
}
