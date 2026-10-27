import '../../../core/files/file_service.dart';
import '../../../core/time/time_utils.dart';
import '../../punch/domain/models.dart';
import '../../schedule/domain/work_schedule.dart';
import '../domain/overtime_report_exporter.dart';
import 'overtime_workbook_builder.dart';

final class ExcelOvertimeReportExporter implements OvertimeReportExporter {
  const ExcelOvertimeReportExporter({this.fileService = const FileService()});

  final FileService fileService;

  @override
  Future<OvertimeReportGenerationResult> exportMonth(
    MonthSummary month,
    WorkSchedule schedule,
    String outputDirectory,
  ) async {
    final workbook = OvertimeWorkbookBuilder().build(month, schedule);
    final filename = overtimeReportFilenameForMonth(
      DateTime(month.year, month.month),
    );
    final outputPath = await fileService.writeUniqueAtomically(
      outputDirectory,
      filename,
      workbook.bytes,
    );
    return OvertimeReportGenerationResult(
      outputPath: outputPath,
      totalOvertimeMinutes: workbook.totalOvertimeMinutes,
      evaluatedDays: workbook.evaluatedDays,
      overtimeDays: workbook.overtimeDays,
      pendingDays: workbook.pendingDays,
      monthYear: workbook.monthYear,
    );
  }
}

String overtimeReportFilenameForMonth(DateTime date) =>
    'horas_extras_${monthsPtSlug[date.month]}_${date.year}.xlsx';
