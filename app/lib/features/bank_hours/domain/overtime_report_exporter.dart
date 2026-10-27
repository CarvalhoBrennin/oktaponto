import '../../punch/domain/models.dart';
import '../../schedule/domain/work_schedule.dart';

final class OvertimeReportGenerationResult {
  const OvertimeReportGenerationResult({
    required this.outputPath,
    required this.totalOvertimeMinutes,
    required this.evaluatedDays,
    required this.overtimeDays,
    required this.pendingDays,
    required this.monthYear,
  });

  final String outputPath;
  final int totalOvertimeMinutes;
  final int evaluatedDays;
  final int overtimeDays;
  final int pendingDays;
  final String monthYear;
}

abstract interface class OvertimeReportExporter {
  Future<OvertimeReportGenerationResult> exportMonth(
    MonthSummary month,
    WorkSchedule schedule,
    String outputDirectory,
  );
}
