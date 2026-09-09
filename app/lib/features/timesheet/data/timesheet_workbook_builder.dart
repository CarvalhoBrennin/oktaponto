import 'package:excel_plus/excel_plus.dart';

import '../../../core/time/time_utils.dart';
import '../../month_close/domain/monthly_close_validator.dart';
import '../../punch/domain/models.dart';
import '../domain/xlsx_safe_text.dart';

final class BuiltTimesheetWorkbook {
  const BuiltTimesheetWorkbook({
    required this.bytes,
    required this.includedDays,
    required this.totalMinutes,
    required this.periodStart,
    required this.periodEnd,
    required this.monthYear,
  });

  final List<int> bytes;
  final int includedDays;
  final int totalMinutes;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String monthYear;
}

/// Pure Dart workbook builder. It deliberately has no filesystem, Flutter,
/// sharing or platform-plugin dependency so it can be exercised from `dart run`
/// and compared against the temporary Python migration oracle in CI.
final class TimesheetWorkbookBuilder {
  const TimesheetWorkbookBuilder({
    this.validator = const DefaultMonthlyCloseValidator(),
  });

  final MonthlyCloseValidator validator;

  static ExcelColor _c(String hex) => ExcelColor.fromHexString('#$hex');
  static const _font = 'Segoe UI';
  static final _thin = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: _c('C8D8EC'),
  );
  static final _mediumBlue = Border(
    borderStyle: BorderStyle.Medium,
    borderColorHex: _c('2E75B6'),
  );
  static final _mediumHeader = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: _c('1A5C9E'),
  );

  CellStyle _style({
    String fg = '1F3864',
    String bg = 'FFFFFF',
    int size = 10,
    bool bold = false,
    bool italic = false,
    HorizontalAlign horizontal = HorizontalAlign.Left,
    VerticalAlign vertical = VerticalAlign.Center,
    Border? left,
    Border? right,
    Border? top,
    Border? bottom,
    NumFormat? numberFormat,
  }) =>
      CellStyle(
        fontFamily: _font,
        fontSize: size,
        bold: bold,
        italic: italic,
        fontColorHex: _c(fg),
        backgroundColorHex: _c(bg),
        fillPattern: FillPatternType.solid,
        horizontalAlign: horizontal,
        verticalAlign: vertical,
        leftBorder: left,
        rightBorder: right,
        topBorder: top,
        bottomBorder: bottom,
        numberFormat: numberFormat ?? NumFormat.standard_0,
      );

  void _text(Sheet sheet, String cell, String value, CellStyle style) {
    sheet.updateCell(
      CellIndex.indexByString(cell),
      TextCellValue(XlsxSafeText.sanitize(value)),
      cellStyle: style,
    );
  }

  BuiltTimesheetWorkbook build(
    MonthSummary month,
    ProfileSettingsModel profile,
  ) {
    final validation = validator.validate(month);
    if (!validation.isValid) {
      throw StateError(
        validation.issues
            .where((issue) => issue.blocking)
            .map((issue) => issue.message)
            .join('\n'),
      );
    }
    if (profile.employeeName.trim().isEmpty ||
        profile.jobTitle.trim().isEmpty ||
        profile.workMode.trim().isEmpty) {
      throw StateError(
        'Preencha colaborador, cargo e modalidade antes de exportar.',
      );
    }

    final included = month.days.where((day) => day.isEligibleForTimesheet).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (included.isEmpty) {
      throw StateError('Nenhum dia elegível para exportação.');
    }

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Planilha1');
    excel.setDefaultSheet('Planilha1');
    final sheet = excel['Planilha1'];
    sheet.showGridLines = false;
    sheet.freezePanes(rows: 6);

    const widths = [13.0, 18.0, 17.0, 25.0, 22.0, 22.0, 52.0];
    for (var index = 0; index < widths.length; index++) {
      sheet.setColumnWidth(index, widths[index]);
    }

    sheet.setRowHeight(0, 36);
    sheet.setRowHeight(4, 8);
    for (var col = 0; col < 7; col++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 4))
          .cellStyle = CellStyle(
        backgroundColorHex: _c('FFFFFF'),
        fillPattern: FillPatternType.solid,
      );
    }
    sheet.setRowHeight(5, 28);

    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('G1'),
    );
    _text(
      sheet,
      'A1',
      '⏱  TIMESHEET — ${monthsPtUpper[month.month]} ${month.year}',
      _style(
        fg: 'FFFFFF',
        bg: '1F3864',
        size: 16,
        bold: true,
        horizontal: HorizontalAlign.Center,
      ),
    );

    final bounds = monthBounds(DateTime(month.year, month.month));
    for (var row = 1; row <= 3; row++) {
      sheet.setRowHeight(row, 18);
    }

    final info = <(int, String, String)>[
      (2, 'COLABORADOR', profile.employeeName),
      (3, 'CARGO', profile.jobTitle),
      (
        4,
        'PERÍODO',
        '${formatDateBr(bounds.$1)}  →  ${formatDateBr(bounds.$2)}',
      ),
    ];
    for (final item in info) {
      final row = item.$1;
      sheet.merge(
        CellIndex.indexByString('A$row'),
        CellIndex.indexByString('B$row'),
      );
      sheet.merge(
        CellIndex.indexByString('C$row'),
        CellIndex.indexByString('G$row'),
      );
      _text(
        sheet,
        'A$row',
        item.$2,
        _style(
          fg: '2E75B6',
          bg: 'EEF4FB',
          size: 9,
          bold: true,
          left: _mediumBlue,
        ),
      );
      _text(
        sheet,
        'C$row',
        item.$3,
        _style(fg: '1F3864', bg: 'EEF4FB', size: 10),
      );
    }

    const headers = [
      'Data',
      'Dia da Semana',
      'Horas Trabalhadas',
      'Colaborador',
      'Cargo',
      'Modalidade',
      'Atividades / Entregas',
    ];
    for (var col = 0; col < headers.length; col++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 5),
        TextCellValue(headers[col]),
        cellStyle: _style(
          fg: 'FFFFFF',
          bg: '2E75B6',
          bold: true,
          horizontal: HorizontalAlign.Center,
          left: _mediumHeader,
          right: _mediumHeader,
          top: _mediumHeader,
          bottom: _mediumHeader,
        ),
      );
    }

    var excelRow = 7;
    var total = 0;
    for (var dayIndex = 0; dayIndex < included.length; dayIndex++) {
      final day = included[dayIndex];
      sheet.setRowHeight(excelRow - 1, 18);
      final special = day.date.weekday >= DateTime.friday;
      final bg = special
          ? 'FFF2CC'
          : (dayIndex.isEven ? 'EEF4FB' : 'FFFFFF');
      final timeColor = day.workedMinutes < 480
          ? 'C00000'
          : day.workedMinutes > 480
              ? '1E7145'
              : '1F3864';
      final base = _style(
        fg: '1F3864',
        bg: bg,
        size: 10,
        left: _thin,
        right: _thin,
        top: _thin,
        bottom: _thin,
      );
      final centered = _style(
        fg: '1F3864',
        bg: bg,
        size: 10,
        horizontal: HorizontalAlign.Center,
        left: _thin,
        right: _thin,
        top: _thin,
        bottom: _thin,
      );

      sheet.updateCell(
        CellIndex.indexByString('A$excelRow'),
        DateCellValue(
          year: day.date.year,
          month: day.date.month,
          day: day.date.day,
        ),
        cellStyle: _style(
          fg: '1F3864',
          bg: bg,
          size: 10,
          horizontal: HorizontalAlign.Center,
          left: _thin,
          right: _thin,
          top: _thin,
          bottom: _thin,
          numberFormat: NumFormat.custom(formatCode: 'DD/MM/YYYY'),
        ),
      );
      _text(sheet, 'B$excelRow', weekdayPt(day.date), base);
      sheet.updateCell(
        CellIndex.indexByString('C$excelRow'),
        DoubleCellValue(day.workedMinutes / 1440.0),
        cellStyle: _style(
          fg: timeColor,
          bg: bg,
          size: 10,
          bold: true,
          horizontal: HorizontalAlign.Center,
          left: _thin,
          right: _thin,
          top: _thin,
          bottom: _thin,
          numberFormat: NumFormat.custom(formatCode: '[h]:mm'),
        ),
      );
      _text(sheet, 'D$excelRow', profile.employeeName, base);
      _text(sheet, 'E$excelRow', profile.jobTitle, base);
      _text(sheet, 'F$excelRow', profile.workMode, centered);

      final activity = (day.activity?.trim().isNotEmpty ?? false)
          ? day.activity!.trim()
          : profile.defaultActivity.trim();
      final activityStyle = _style(
        fg: '000000',
        bg: bg,
        size: 11,
        left: _thin,
        right: _thin,
        top: _thin,
        bottom: _thin,
      );
      if (activity.isEmpty) {
        sheet.cell(CellIndex.indexByString('G$excelRow')).cellStyle =
            activityStyle;
      } else {
        _text(sheet, 'G$excelRow', activity, activityStyle);
      }
      total += day.workedMinutes;
      excelRow++;
    }

    sheet.setRowHeight(excelRow - 1, 6);
    for (var col = 0; col < 7; col++) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: col,
              rowIndex: excelRow - 1,
            ),
          )
          .cellStyle = CellStyle(
        backgroundColorHex: _c('FFFFFF'),
        fillPattern: FillPatternType.solid,
      );
    }

    excelRow++;
    sheet.setRowHeight(excelRow - 1, 28);
    sheet.merge(
      CellIndex.indexByString('A$excelRow'),
      CellIndex.indexByString('B$excelRow'),
    );
    _text(
      sheet,
      'A$excelRow',
      'TOTAL DE HORAS',
      _style(
        fg: 'FFFFFF',
        bg: '1F3864',
        size: 11,
        bold: true,
        horizontal: HorizontalAlign.Center,
        left: _mediumHeader,
        right: _mediumHeader,
        top: _mediumHeader,
        bottom: _mediumHeader,
      ),
    );
    sheet.updateCell(
      CellIndex.indexByString('C$excelRow'),
      DoubleCellValue(total / 1440.0),
      cellStyle: _style(
        fg: 'FFFFFF',
        bg: '1F3864',
        size: 14,
        bold: true,
        horizontal: HorizontalAlign.Center,
        left: _mediumHeader,
        right: _mediumHeader,
        top: _mediumHeader,
        bottom: _mediumHeader,
        numberFormat: NumFormat.custom(formatCode: '[h]:mm'),
      ),
    );
    for (var col = 3; col < 7; col++) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: col,
              rowIndex: excelRow - 1,
            ),
          )
          .cellStyle = CellStyle(
        backgroundColorHex: _c('1F3864'),
        fillPattern: FillPatternType.solid,
        leftBorder: _mediumHeader,
        rightBorder: _mediumHeader,
        topBorder: _mediumHeader,
        bottomBorder: _mediumHeader,
      );
    }

    excelRow += 2;
    sheet.setRowHeight(excelRow - 1, 14);
    sheet.merge(
      CellIndex.indexByString('A$excelRow'),
      CellIndex.indexByString('G$excelRow'),
    );
    _text(
      sheet,
      'A$excelRow',
      '🟢 > 8h  |  🔴 < 8h  |  🔵 = 8h  |  🟡 Sexta / fim de semana',
      CellStyle(
        fontFamily: _font,
        fontSize: 8,
        italic: true,
        fontColorHex: _c('888888'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      ),
    );

    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Falha ao serializar o workbook XLSX.');
    }
    return BuiltTimesheetWorkbook(
      bytes: bytes,
      includedDays: included.length,
      totalMinutes: total,
      periodStart: bounds.$1,
      periodEnd: bounds.$2,
      monthYear: '${monthsPtUpper[month.month]} ${month.year}',
    );
  }
}
