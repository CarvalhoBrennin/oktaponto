import 'package:excel_plus/excel_plus.dart';

import '../../../core/time/time_utils.dart';
import '../../punch/domain/models.dart';
import '../../punch/domain/work_hours_calculator.dart';
import '../../schedule/domain/work_schedule.dart';
import '../../timesheet/domain/xlsx_safe_text.dart';

final class BuiltOvertimeWorkbook {
  const BuiltOvertimeWorkbook({
    required this.bytes,
    required this.totalOvertimeMinutes,
    required this.evaluatedDays,
    required this.overtimeDays,
    required this.pendingDays,
    required this.monthYear,
  });

  final List<int> bytes;
  final int totalOvertimeMinutes;
  final int evaluatedDays;
  final int overtimeDays;
  final int pendingDays;
  final String monthYear;
}

final class OvertimeWorkbookBuilder {
  const OvertimeWorkbookBuilder({
    this.calculator = const DefaultWorkHoursCalculator(),
  });

  final WorkHoursCalculator calculator;

  static ExcelColor _color(String hex) => ExcelColor.fromHexString('#$hex');
  static const _font = 'Segoe UI';
  static final _thin = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: _color('C8D8EC'),
  );

  CellStyle _style({
    String foreground = '1F3864',
    String background = 'FFFFFF',
    int size = 10,
    bool bold = false,
    bool italic = false,
    HorizontalAlign horizontal = HorizontalAlign.Left,
    Border? left,
    Border? right,
    Border? top,
    Border? bottom,
    NumFormat? numberFormat,
  }) => CellStyle(
    fontFamily: _font,
    fontSize: size,
    bold: bold,
    italic: italic,
    fontColorHex: _color(foreground),
    backgroundColorHex: _color(background),
    fillPattern: FillPatternType.solid,
    horizontalAlign: horizontal,
    verticalAlign: VerticalAlign.Center,
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

  BuiltOvertimeWorkbook build(MonthSummary month, WorkSchedule schedule) {
    final scheduleProblem = schedule.problem;
    if (scheduleProblem != null) {
      throw StateError(scheduleProblem);
    }

    final days = <WorkDaySummary>[];
    final seenDates = <String>{};
    var pendingDays = 0;
    for (final day in month.days) {
      final key = localDateKey(day.date);
      if (day.date.year != month.year || day.date.month != month.month) {
        throw StateError('O mês contém um dia fora do período do extrato.');
      }
      if (!seenDates.add(key)) {
        throw StateError('O mês contém datas duplicadas no extrato.');
      }
      if (day.punches.isEmpty) continue;

      final recalculated = calculator.calculate(
        day.date,
        day.punches,
        WorkDayMetadata(
          localDate: key,
          includeInTimesheet: day.includeInTimesheet,
          activity: day.activity,
          note: day.note,
        ),
        schedule: schedule,
      );
      if (recalculated.hasBlockingIssues) {
        throw StateError(
          'Corrija as batidas de ${formatDateBr(day.date)} no Histórico '
          'antes de exportar o extrato.',
        );
      }
      if (day.hasBlockingIssues ||
          day.status != recalculated.status ||
          day.workedMinutes != recalculated.workedMinutes ||
          day.targetMinutes != recalculated.targetMinutes ||
          day.balanceMinutes != recalculated.balanceMinutes) {
        throw StateError(
          'Os dados de ${formatDateBr(day.date)} mudaram ou estão '
          'inconsistentes. Atualize o mês e tente novamente.',
        );
      }
      if (recalculated.status != WorkDayStatus.complete) {
        pendingDays++;
        continue;
      }
      if (!recalculated.isEligibleForBankHours) {
        throw StateError(
          'Não foi possível calcular o saldo de ${formatDateBr(day.date)}.',
        );
      }
      days.add(recalculated);
    }

    days.sort((a, b) => a.date.compareTo(b.date));
    final totalOvertimeMinutes = days.fold<int>(
      0,
      (total, day) => total + day.overtimeMinutes,
    );
    final overtimeDays = days.where((day) => day.overtimeMinutes > 0).length;
    if (days.length != month.bankHoursDayCount ||
        totalOvertimeMinutes != month.overtimeMinutes) {
      throw StateError(
        'O resumo do mês não corresponde às batidas atuais. Atualize o mês '
        'antes de exportar.',
      );
    }

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Horas extras');
    excel.setDefaultSheet('Horas extras');
    final sheet = excel['Horas extras'];
    sheet.showGridLines = false;
    sheet.freezePanes(rows: 7);

    const widths = [14.0, 12.0, 22.0, 22.0, 14.0, 20.0, 18.0, 16.0];
    for (var index = 0; index < widths.length; index++) {
      sheet.setColumnWidth(index, widths[index]);
    }
    sheet.setRowHeight(0, 36);
    sheet.setRowHeight(1, 22);
    sheet.setRowHeight(3, 24);
    sheet.setRowHeight(4, 25);
    sheet.setRowHeight(6, 30);

    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('H1'));
    _text(
      sheet,
      'A1',
      'EXTRATO DE HORAS EXTRAS — ${monthsPtUpper[month.month]} ${month.year}',
      _style(
        foreground: 'FFFFFF',
        background: '1F3864',
        size: 16,
        bold: true,
        horizontal: HorizontalAlign.Center,
      ),
    );
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('H2'));
    final bounds = monthBounds(DateTime(month.year, month.month));
    _text(
      sheet,
      'A2',
      'Período: ${formatDateBr(bounds.$1)} a ${formatDateBr(bounds.$2)}',
      _style(foreground: '2E75B6', size: 10, bold: true),
    );

    _mergeText(sheet, 'A4', 'B4', 'TOTAL DE HORAS EXTRAS', _summaryLabelStyle);
    _mergeDuration(sheet, 'C4', 'D4', totalOvertimeMinutes, _summaryValueStyle);
    _mergeText(sheet, 'E4', 'F4', 'DIAS COM EXTRAS', _summaryLabelStyle);
    _mergeText(sheet, 'G4', 'H4', '$overtimeDays', _summaryValueStyle);

    sheet.merge(CellIndex.indexByString('A5'), CellIndex.indexByString('H5'));
    _text(
      sheet,
      'A5',
      pendingDays == 0
          ? 'O total considera dias completos e consistentes.'
          : '$pendingDays ${pendingDays == 1 ? 'dia incompleto foi excluído' : 'dias incompletos foram excluídos'} do total.',
      _style(
        foreground: pendingDays == 0 ? '1E7145' : '8A5A00',
        background: pendingDays == 0 ? 'EEF4FB' : 'FFF2CC',
        size: 9,
        italic: true,
      ),
    );

    const headers = [
      'Data',
      'Entrada',
      'Saída para intervalo',
      'Retorno do intervalo',
      'Saída final',
      'Horas trabalhadas',
      'Meta diária',
      'Horas extras',
    ];
    for (var column = 0; column < headers.length; column++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 6),
        TextCellValue(headers[column]),
        cellStyle: _style(
          foreground: 'FFFFFF',
          background: '2E75B6',
          size: 9,
          bold: true,
          horizontal: HorizontalAlign.Center,
          left: _thin,
          right: _thin,
          top: _thin,
          bottom: _thin,
        ),
      );
    }

    var excelRow = 8;
    for (var index = 0; index < days.length; index++) {
      final day = days[index];
      final background = day.date.weekday >= DateTime.saturday
          ? 'FFF2CC'
          : index.isEven
          ? 'EEF4FB'
          : 'FFFFFF';
      final centered = _style(
        background: background,
        horizontal: HorizontalAlign.Center,
        left: _thin,
        right: _thin,
        top: _thin,
        bottom: _thin,
      );
      sheet.setRowHeight(excelRow - 1, 22);
      sheet.updateCell(
        CellIndex.indexByString('A$excelRow'),
        DateCellValue(
          year: day.date.year,
          month: day.date.month,
          day: day.date.day,
        ),
        cellStyle: _style(
          background: background,
          horizontal: HorizontalAlign.Center,
          left: _thin,
          right: _thin,
          top: _thin,
          bottom: _thin,
          numberFormat: NumFormat.custom(formatCode: 'DD/MM/YYYY'),
        ),
      );
      final punchTimes = day.punches
          .map((punch) => formatClock(punch.occurredAtLocal))
          .toList();
      for (var punchIndex = 0; punchIndex < 4; punchIndex++) {
        _text(
          sheet,
          '${String.fromCharCode(66 + punchIndex)}$excelRow',
          punchTimes[punchIndex],
          centered,
        );
      }
      _durationCell(sheet, 'F$excelRow', day.workedMinutes, centered);
      _durationCell(sheet, 'G$excelRow', day.targetMinutes!, centered);
      _durationCell(
        sheet,
        'H$excelRow',
        day.overtimeMinutes,
        _style(
          foreground: day.overtimeMinutes > 0 ? '1E7145' : '1F3864',
          background: background,
          bold: day.overtimeMinutes > 0,
          horizontal: HorizontalAlign.Center,
          left: _thin,
          right: _thin,
          top: _thin,
          bottom: _thin,
        ),
      );
      excelRow++;
    }

    if (days.isEmpty) {
      sheet.merge(
        CellIndex.indexByString('A$excelRow'),
        CellIndex.indexByString('H$excelRow'),
      );
      _text(
        sheet,
        'A$excelRow',
        'Nenhum dia completo com batidas foi encontrado neste período.',
        _style(foreground: '6B6660', italic: true),
      );
      excelRow++;
    }

    excelRow++;
    sheet.merge(
      CellIndex.indexByString('A$excelRow'),
      CellIndex.indexByString('H$excelRow'),
    );
    _text(
      sheet,
      'A$excelRow',
      'O total de horas extras soma apenas o tempo acima da meta diária. '
          'Este extrato não calcula valores em dinheiro.',
      _style(foreground: '6B6660', size: 9, italic: true),
    );

    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Falha ao serializar o extrato de horas extras.');
    }
    return BuiltOvertimeWorkbook(
      bytes: bytes,
      totalOvertimeMinutes: totalOvertimeMinutes,
      evaluatedDays: days.length,
      overtimeDays: overtimeDays,
      pendingDays: pendingDays,
      monthYear: '${monthsPtUpper[month.month]} ${month.year}',
    );
  }

  CellStyle get _summaryLabelStyle => _style(
    foreground: '2E75B6',
    background: 'EEF4FB',
    size: 9,
    bold: true,
    horizontal: HorizontalAlign.Center,
    left: _thin,
    right: _thin,
    top: _thin,
    bottom: _thin,
  );

  CellStyle get _summaryValueStyle => _style(
    foreground: '1F3864',
    background: 'EEF4FB',
    size: 12,
    bold: true,
    horizontal: HorizontalAlign.Center,
    left: _thin,
    right: _thin,
    top: _thin,
    bottom: _thin,
  );

  void _mergeText(
    Sheet sheet,
    String start,
    String end,
    String value,
    CellStyle style,
  ) {
    sheet.merge(CellIndex.indexByString(start), CellIndex.indexByString(end));
    _text(sheet, start, value, style);
  }

  void _mergeDuration(
    Sheet sheet,
    String start,
    String end,
    int minutes,
    CellStyle style,
  ) {
    sheet.merge(CellIndex.indexByString(start), CellIndex.indexByString(end));
    sheet.updateCell(
      CellIndex.indexByString(start),
      DoubleCellValue(minutes / 1440.0),
      cellStyle: style.copyWith(
        numberFormat: const CustomNumericNumFormat(formatCode: '[h]:mm'),
      ),
    );
  }

  void _durationCell(Sheet sheet, String cell, int minutes, CellStyle style) {
    sheet.updateCell(
      CellIndex.indexByString(cell),
      DoubleCellValue(minutes / 1440.0),
      cellStyle: style.copyWith(
        numberFormat: const CustomNumericNumFormat(formatCode: '[h]:mm'),
      ),
    );
  }
}
