import '../../../core/files/file_service.dart';
import '../../../core/time/time_utils.dart';
import '../../month_close/domain/monthly_close_validator.dart';
import '../../punch/domain/models.dart';
import '../domain/timesheet_exporter.dart';
import 'timesheet_workbook_builder.dart';

final class ExcelTimesheetExporter implements TimesheetExporter {
  const ExcelTimesheetExporter({
    this.validator = const DefaultMonthlyCloseValidator(),
    this.fileService = const FileService(),
  });

  final MonthlyCloseValidator validator;
  final FileService fileService;

  @override
  Future<TimesheetGenerationResult> exportMonth(
    MonthSummary month,
    ProfileSettingsModel profile,
    String outputDirectory,
  ) async {
    final workbook = TimesheetWorkbookBuilder(validator: validator).build(
      month,
      profile,
    );
    final filename = defaultFilenameForMonth(
      DateTime(month.year, month.month),
    );
    final outputPath = await fileService.writeUniqueAtomically(
      outputDirectory,
      filename,
      workbook.bytes,
    );
    return TimesheetGenerationResult(
      outputPath: outputPath,
      includedDays: workbook.includedDays,
      totalMinutes: workbook.totalMinutes,
      periodStart: workbook.periodStart,
      periodEnd: workbook.periodEnd,
      monthYear: workbook.monthYear,
    );
  }
}
