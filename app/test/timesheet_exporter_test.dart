import 'dart:io';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/features/punch/domain/models.dart';
import 'package:horafolio/features/timesheet/data/excel_timesheet_exporter.dart';
import 'package:horafolio/features/timesheet/domain/xlsx_safe_text.dart';

WorkDaySummary complete(DateTime date, int minutes, {String? activity}) {
  final first = 240;
  final second = minutes - first;
  final start = DateTime.utc(date.year, date.month, date.day, 8);
  final punches = <Punch>[
    Punch(id: 1, occurredAtUtc: start, localDate: _key(date), utcOffsetMinutes: 0, kind: PunchKind.in_, isEdited: false),
    Punch(id: 2, occurredAtUtc: start.add(Duration(minutes: first)), localDate: _key(date), utcOffsetMinutes: 0, kind: PunchKind.out, isEdited: false),
    Punch(id: 3, occurredAtUtc: DateTime.utc(date.year, date.month, date.day, 13), localDate: _key(date), utcOffsetMinutes: 0, kind: PunchKind.in_, isEdited: false),
    Punch(id: 4, occurredAtUtc: DateTime.utc(date.year, date.month, date.day, 13).add(Duration(minutes: second)), localDate: _key(date), utcOffsetMinutes: 0, kind: PunchKind.out, isEdited: false),
  ];
  return WorkDaySummary(
    date: date,
    punches: punches,
    status: WorkDayStatus.complete,
    workedMinutes: minutes,
    includeInTimesheet: true,
    activity: activity,
    issues: const [],
  );
}

String _key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  test('sanitizes illegal XML controls without interpreting formulas', () {
    expect(XlsxSafeText.sanitize('a\u0007b'), 'a b');
    expect(XlsxSafeText.sanitize('=HYPERLINK("x")'), '=HYPERLINK("x")');
  });

  test('exports numeric duration, safe text, freeze panes and no-overwrite', () async {
    final dir = await Directory.systemTemp.createTemp('horafolio_xlsx_');
    addTearDown(() => dir.delete(recursive: true));
    const profile = ProfileSettingsModel(employeeName: 'Pessoa', jobTitle: 'Dev', workMode: 'Presencial', defaultActivity: 'Padrão');
    final month = MonthSummary(year: 2026, month: 9, days: [
      complete(DateTime(2026, 9, 1), 480, activity: '=HYPERLINK("https://example.invalid")'),
      complete(DateTime(2026, 9, 4), 479),
    ]);
    const exporter = ExcelTimesheetExporter();
    final results = await Future.wait(List.generate(4, (_) => exporter.exportMonth(month, profile, dir.path)));
    expect(results.map((r) => r.outputPath).toSet().length, 4);
    final excel = Excel.decodeBytes(await File(results.first.outputPath).readAsBytes());
    final sheet = excel['Planilha1'];
    expect(sheet.showGridLines, isFalse);
    expect(sheet.frozenRows, 6);
    expect(sheet.cell(CellIndex.indexByString('C7')).value, isA<DoubleCellValue>());
    expect(sheet.cell(CellIndex.indexByString('G7')).value, isA<TextCellValue>());
    expect(sheet.cell(CellIndex.indexByString('G7')).value.toString(), contains('HYPERLINK'));
    expect(sheet.cell(CellIndex.indexByString('G8')).value.toString(), contains('Padrão'));
    expect(sheet.cell(CellIndex.indexByString('C7')).cellStyle?.numberFormat.formatCode, '[h]:mm');
  });
}
