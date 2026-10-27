import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/features/bank_hours/data/overtime_workbook_builder.dart';
import 'package:oktaponto/features/punch/domain/models.dart';
import 'package:oktaponto/features/punch/domain/work_hours_calculator.dart';
import 'package:oktaponto/features/schedule/domain/work_schedule.dart';

final _calculator = DefaultWorkHoursCalculator();

void main() {
  test('builds a separate detailed overtime workbook from punch data', () {
    final month = MonthSummary(
      year: 2026,
      month: 9,
      days: [
        _day(DateTime(2026, 9, 1), [
          _p(DateTime(2026, 9, 1), 1, 9, 0, PunchKind.in_),
          _p(DateTime(2026, 9, 1), 2, 12, 0, PunchKind.out),
          _p(DateTime(2026, 9, 1), 3, 13, 0, PunchKind.in_),
          _p(DateTime(2026, 9, 1), 4, 19, 0, PunchKind.out),
        ]),
        _day(DateTime(2026, 9, 2), [
          _p(DateTime(2026, 9, 2), 5, 9, 0, PunchKind.in_),
          _p(DateTime(2026, 9, 2), 6, 12, 0, PunchKind.out),
          _p(DateTime(2026, 9, 2), 7, 13, 0, PunchKind.in_),
          _p(DateTime(2026, 9, 2), 8, 18, 0, PunchKind.out),
        ]),
        _day(DateTime(2026, 9, 3), [
          _p(DateTime(2026, 9, 3), 9, 9, 0, PunchKind.in_),
          _p(DateTime(2026, 9, 3), 10, 12, 0, PunchKind.out),
          _p(DateTime(2026, 9, 3), 11, 13, 0, PunchKind.in_),
        ]),
      ],
    );

    final workbook = const OvertimeWorkbookBuilder().build(
      month,
      WorkSchedule.defaults,
    );
    final sheet = Excel.decodeBytes(workbook.bytes)['Horas extras'];

    expect(workbook.totalOvertimeMinutes, 60);
    expect(workbook.evaluatedDays, 2);
    expect(workbook.overtimeDays, 1);
    expect(workbook.pendingDays, 1);
    expect(sheet.showGridLines, isFalse);
    expect(sheet.frozenRows, 7);
    expect(
      sheet.cell(CellIndex.indexByString('A1')).value.toString(),
      contains('EXTRATO DE HORAS EXTRAS'),
    );
    expect(
      sheet.cell(CellIndex.indexByString('B8')).value,
      isA<TextCellValue>(),
    );
    expect(
      (sheet.cell(CellIndex.indexByString('B8')).value as TextCellValue)
          .value
          .text,
      '09:00',
    );
    expect(_durationMinutes(sheet, 'F8'), 9 * 60);
    expect(_durationMinutes(sheet, 'H8'), 60);
    expect(_durationMinutes(sheet, 'H9'), 0);
    expect(
      sheet.cell(CellIndex.indexByString('A5')).value.toString(),
      contains('1 dia incompleto foi excluído'),
    );
  });

  test('fails closed when punches are inconsistent', () {
    final invalidDay = _day(DateTime(2026, 9, 1), [
      _p(DateTime(2026, 9, 1), 1, 9, 0, PunchKind.in_),
      _p(
        DateTime(2026, 9, 1),
        2,
        12,
        0,
        PunchKind.out,
        localDate: '2026-09-02',
      ),
      _p(DateTime(2026, 9, 1), 3, 13, 0, PunchKind.in_),
      _p(DateTime(2026, 9, 1), 4, 19, 0, PunchKind.out),
    ]);
    final month = MonthSummary(year: 2026, month: 9, days: [invalidDay]);

    expect(
      () => const OvertimeWorkbookBuilder().build(month, WorkSchedule.defaults),
      throwsStateError,
    );
  });
}

WorkDaySummary _day(DateTime date, List<Punch> punches) =>
    _calculator.calculate(
      date,
      punches,
      WorkDayMetadata(localDate: _dateKey(date)),
      schedule: WorkSchedule.defaults,
    );

Punch _p(
  DateTime date,
  int id,
  int hour,
  int minute,
  PunchKind kind, {
  String? localDate,
}) {
  final key = _dateKey(date);
  final occurredAtUtc = DateTime.utc(
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  );
  return Punch(
    id: id,
    occurredAtUtc: occurredAtUtc,
    localDate: localDate ?? key,
    utcOffsetMinutes: 0,
    kind: kind,
    isEdited: false,
  );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

int _durationMinutes(Sheet sheet, String cell) {
  final value = sheet.cell(CellIndex.indexByString(cell)).value;
  if (value is DoubleCellValue) return (value.value * 1440).round();
  if (value is TimeCellValue) return value.asDuration().inMinutes;
  throw StateError('Expected numeric duration in $cell, got $value.');
}
