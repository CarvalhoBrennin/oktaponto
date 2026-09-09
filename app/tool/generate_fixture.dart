import 'dart:convert';
import 'dart:io';

import 'package:horafolio/features/month_close/domain/monthly_close_validator.dart';
import 'package:horafolio/features/punch/domain/models.dart';
import 'package:horafolio/features/timesheet/data/timesheet_workbook_builder.dart';

Future<void> main(List<String> args) async {
  String? fixture;
  String? output;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--fixture' && i + 1 < args.length) fixture = args[++i];
    if (args[i] == '--output' && i + 1 < args.length) output = args[++i];
  }
  if (fixture == null || output == null) {
    stderr.writeln(
      'Uso: dart run tool/generate_fixture.dart --fixture <json> --output <xlsx>',
    );
    exitCode = 64;
    return;
  }

  final payload = jsonDecode(await File(fixture).readAsString())
      as Map<String, dynamic>;
  final profileMap = payload['profile'] as Map<String, dynamic>;
  final profile = ProfileSettingsModel(
    employeeName: profileMap['employee_name'] as String,
    jobTitle: profileMap['job_title'] as String,
    workMode: profileMap['work_mode'] as String,
    defaultActivity: profileMap['default_activity'] as String,
  );

  final days = <WorkDaySummary>[];
  for (final raw in payload['days'] as List<dynamic>) {
    final item = raw as Map<String, dynamic>;
    final date = DateTime.parse(item['date'] as String);
    days.add(
      WorkDaySummary(
        date: date,
        punches: const [],
        status: WorkDayStatus.complete,
        workedMinutes: item['worked_minutes'] as int,
        includeInTimesheet: item['include'] as bool? ?? true,
        activity: item['activity'] as String?,
        issues: const [],
      ),
    );
  }

  final month = MonthSummary(
    year: payload['year'] as int,
    month: payload['month'] as int,
    days: days,
  );
  final requested = File(output);
  await requested.parent.create(recursive: true);
  final workbook = const TimesheetWorkbookBuilder(
    validator: _ContractFixtureValidator(),
  ).build(month, profile);
  await requested.writeAsBytes(workbook.bytes, flush: true);
  stdout.writeln(requested.path);
}


/// Contract fixtures deliberately exercise XLSX representations (including a
/// 24:00 cell) independently from production punch-domain eligibility.
final class _ContractFixtureValidator implements MonthlyCloseValidator {
  const _ContractFixtureValidator();

  @override
  MonthValidationResult validate(MonthSummary month) =>
      const MonthValidationResult([]);
}
