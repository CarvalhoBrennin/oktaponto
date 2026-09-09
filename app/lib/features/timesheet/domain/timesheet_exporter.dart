import '../../punch/domain/models.dart';

abstract interface class TimesheetExporter {
  Future<TimesheetGenerationResult> exportMonth(
    MonthSummary month,
    ProfileSettingsModel profile,
    String outputDirectory,
  );
}
