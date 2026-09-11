import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/features/punch/domain/models.dart';
import 'package:oktaponto/features/punch/domain/work_hours_calculator.dart';
import 'package:oktaponto/features/schedule/domain/work_schedule.dart';

Punch p(int id, int hour, int minute, PunchKind kind) => _pAt(
  DateTime(2026, 9, 1),
  id,
  hour,
  minute,
  kind,
);

Punch _pAt(
  DateTime date,
  int id,
  int hour,
  int minute,
  PunchKind kind,
) => Punch(
  id: id,
  occurredAtUtc: DateTime.utc(date.year, date.month, date.day, hour, minute),
  localDate:
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}',
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

  group('banco de horas', () {
    const schedule = WorkSchedule.defaults;

    test('derives positive overtime from a complete day', () {
      final summary = calculator.calculate(
        DateTime(2026, 9, 1),
        [
          p(1, 8, 0, PunchKind.in_),
          p(2, 12, 0, PunchKind.out),
          p(3, 13, 0, PunchKind.in_),
          p(4, 18, 0, PunchKind.out),
        ],
        metadata,
        schedule: schedule,
      );

      expect(summary.targetMinutes, 480);
      expect(summary.workedMinutes, 540);
      expect(summary.balanceMinutes, 60);
      expect(summary.overtimeMinutes, 60);
      expect(summary.isEligibleForBankHours, isTrue);
    });

    test('keeps a negative balance without counting it as overtime', () {
      final summary = calculator.calculate(
        DateTime(2026, 9, 1),
        [
          p(1, 9, 0, PunchKind.in_),
          p(2, 12, 0, PunchKind.out),
          p(3, 13, 0, PunchKind.in_),
          p(4, 17, 0, PunchKind.out),
        ],
        metadata,
        schedule: schedule,
      );

      expect(summary.balanceMinutes, -60);
      expect(summary.overtimeMinutes, 0);
      expect(summary.isEligibleForBankHours, isTrue);
    });

    test('does not derive a bank movement for an incomplete day', () {
      final summary = calculator.calculate(
        DateTime(2026, 9, 1),
        [
          p(1, 8, 0, PunchKind.in_),
          p(2, 12, 0, PunchKind.out),
        ],
        metadata,
        schedule: schedule,
      );

      expect(summary.targetMinutes, 480);
      expect(summary.balanceMinutes, isNull);
      expect(summary.overtimeMinutes, 0);
      expect(summary.isEligibleForBankHours, isFalse);
    });

    test('bank movement is independent from timesheet inclusion', () {
      final summary = calculator.calculate(
        DateTime(2026, 9, 1),
        [
          p(1, 8, 0, PunchKind.in_),
          p(2, 12, 0, PunchKind.out),
          p(3, 13, 0, PunchKind.in_),
          p(4, 18, 0, PunchKind.out),
        ],
        const WorkDayMetadata(
          localDate: '2026-09-01',
          includeInTimesheet: false,
        ),
        schedule: schedule,
      );

      expect(summary.isEligibleForTimesheet, isFalse);
      expect(summary.overtimeMinutes, 60);
      expect(summary.isEligibleForBankHours, isTrue);
    });

    test('does not derive bank values from an invalid schedule', () {
      final summary = calculator.calculate(
        DateTime(2026, 9, 1),
        [
          p(1, 8, 0, PunchKind.in_),
          p(2, 12, 0, PunchKind.out),
          p(3, 13, 0, PunchKind.in_),
          p(4, 18, 0, PunchKind.out),
        ],
        metadata,
        schedule: schedule.copyWith(endMinuteOfDay: 6 * 60),
      );

      expect(summary.targetMinutes, isNull);
      expect(summary.balanceMinutes, isNull);
      expect(summary.isEligibleForBankHours, isFalse);
    });

    test('counts a complete day outside the configured weekdays as overtime', () {
      final summary = calculator.calculate(
        DateTime(2026, 9, 5),
        [
          _pAt(DateTime(2026, 9, 5), 1, 8, 0, PunchKind.in_),
          _pAt(DateTime(2026, 9, 5), 2, 12, 0, PunchKind.out),
          _pAt(DateTime(2026, 9, 5), 3, 13, 0, PunchKind.in_),
          _pAt(DateTime(2026, 9, 5), 4, 17, 0, PunchKind.out),
        ],
        const WorkDayMetadata(localDate: '2026-09-05'),
        schedule: schedule,
      );

      expect(summary.targetMinutes, 0);
      expect(summary.overtimeMinutes, 480);
      expect(summary.isEligibleForBankHours, isTrue);
    });

    test('month summary exposes overtime and net bank balance', () {
      final extra = calculator.calculate(
        DateTime(2026, 9, 1),
        [
          p(1, 8, 0, PunchKind.in_),
          p(2, 12, 0, PunchKind.out),
          p(3, 13, 0, PunchKind.in_),
          p(4, 18, 0, PunchKind.out),
        ],
        metadata,
        schedule: schedule,
      );
      final deficit = calculator.calculate(
        DateTime(2026, 9, 2),
        [
          _pAt(DateTime(2026, 9, 2), 5, 9, 0, PunchKind.in_),
          _pAt(DateTime(2026, 9, 2), 6, 12, 0, PunchKind.out),
          _pAt(DateTime(2026, 9, 2), 7, 13, 0, PunchKind.in_),
          _pAt(DateTime(2026, 9, 2), 8, 17, 0, PunchKind.out),
        ],
        const WorkDayMetadata(localDate: '2026-09-02'),
        schedule: schedule,
      );
      final month = MonthSummary(
        year: 2026,
        month: 9,
        days: [deficit, extra],
      );

      expect(month.overtimeMinutes, 60);
      expect(month.bankBalanceMinutes, 0);
      expect(month.bankHoursDayCount, 2);
      expect(month.daysWithOvertime, [extra]);
      expect(month.daysWithDeficit, [deficit]);
    });
  });
}
