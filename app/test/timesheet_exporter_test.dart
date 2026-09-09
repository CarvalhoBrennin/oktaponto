import 'dart:io';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/features/punch/domain/models.dart';
import 'package:horafolio/features/timesheet/data/excel_timesheet_exporter.dart';
import 'package:horafolio/features/timesheet/domain/xlsx_safe_text.dart';

WorkDaySummary complete(DateTime date, int minutes, {String? activity}) => WorkDaySummary(
      date: date,
      punches: const [],
      status: WorkDayStatus.complete,
      workedMinutes: minutes,
      includeInTimesheet: true,
      activity: activity,
      issues: const [],
    );

void main() {
  test('sanitizes illegal XML controls without interpreting formulas', () {
    expect(XlsxSafeText.sanitize('a\u0007b'), 'a b');
    expect(XlsxSafeText.sanitize('=HYPERLINK("x")'), '=HYPERLINK("x")');
  });

  test('exports numeric duration, safe text, freeze panes and no-overwrite', () async {
    final dir = await Directory.systemTemp.createTemp('horafolio_xlsx_');
    addTearDown(() => dir.delete(recursive: true));
    const profile = ProfileSettingsModel(
      employeeName: 'Pessoa',
      jobTitle: 'Dev',
      workMode: 'Presencial',
      defaultActivity: 'Padrão',
    );
    final month = MonthSummary(year: 2026, month: 9, days: [
      complete(DateTime(2026, 9, 1), 480, activity: '=HYPERLINK("https://example.invalid")'),
      complete(DateTime(2026, 9, 4), 479),
    ]);
    final exporter = const ExcelTimesheetExporter();
    final first = await exporter.exportMonth(month, profile, dir.path);
    final second = await exporter.exportMonth(month, profile, dir.path);
    expect(first.outputPath, isNot(second.outputPath));
    final excel = Excel.decodeBytes(await File(first.outputPath).readAsBytes());
    final sheet = excel['Planilha1'];
    expect(sheet.showGridLines, isFalse);
    expect(sheet.frozenRows, 6);
    expect(sheet.cell(CellIndex.indexByString('C7')).value, isA<DoubleCellValue>());
    expect(sheet.cell(CellIndex.indexByString('G7')).value, isA<TextCellValue>());
    expect(sheet.cell(CellIndex.indexByString('G7')).value.toString(), contains('HYPERLINK'));
  });

  test('rejects an invalid included day', () async {
    final dir = await Directory.systemTemp.createTemp('horafolio_invalid_');
    addTearDown(() => dir.delete(recursive: true));
    final month = MonthSummary(year: 2026, month: 9, days: [
      WorkDaySummary(
        date: DateTime(2026, 9, 1),
        punches: const [],
        status: WorkDayStatus.open,
        workedMinutes: 120,
        includeInTimesheet: true,
        activity: null,
        issues: const [],
      ),
    ]);
    await expectLater(
      const ExcelTimesheetExporter().exportMonth(
        month,
        const ProfileSettingsModel(employeeName: 'A', jobTitle: 'B', workMode: 'C'),
        dir.path,
      ),
      throwsStateError,
    );
  });
}
