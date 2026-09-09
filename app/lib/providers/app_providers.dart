import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/files/file_service.dart';
import '../core/time/time_utils.dart';
import '../features/month_close/domain/monthly_close_validator.dart';
import '../features/punch/data/drift_repositories.dart';
import '../features/punch/domain/models.dart';
import '../features/punch/domain/punch_service.dart';
import '../features/punch/domain/repositories.dart';
import '../features/punch/domain/work_hours_calculator.dart';
import '../features/reminders/data/local_notification_service.dart';
import '../features/reminders/domain/reminder.dart';
import '../features/settings/domain/data_reset_service.dart';
import '../features/timesheet/data/excel_timesheet_exporter.dart';
import '../features/timesheet/data/share_service.dart';
import '../features/timesheet/domain/timesheet_exporter.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final punchRepositoryProvider = Provider<PunchRepository>((ref) => DriftPunchRepository(ref.watch(databaseProvider)));
final workDayRepositoryProvider = Provider<WorkDayRepository>((ref) => DriftWorkDayRepository(ref.watch(databaseProvider)));
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => DriftSettingsRepository(ref.watch(databaseProvider)));
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) => DriftReminderRepository(ref.watch(databaseProvider)));
final clockProvider = Provider<Clock>((ref) => Clock());
final workHoursCalculatorProvider = Provider<WorkHoursCalculator>((ref) => const DefaultWorkHoursCalculator());
final monthlyValidatorProvider = Provider<MonthlyCloseValidator>((ref) => const DefaultMonthlyCloseValidator());
final punchServiceProvider = Provider<PunchService>(
  (ref) => DefaultPunchService(repository: ref.watch(punchRepositoryProvider), timeClock: ref.watch(clockProvider)),
);
final fileServiceProvider = Provider<FileService>((ref) => const FileService());
final timesheetExporterProvider = Provider<TimesheetExporter>(
  (ref) => ExcelTimesheetExporter(validator: ref.watch(monthlyValidatorProvider), fileService: ref.watch(fileServiceProvider)),
);
final shareServiceProvider = Provider<FileShareService>((ref) => const NativeFileShareService());
final notificationServiceProvider = Provider<LocalNotificationService>((ref) => LocalNotificationService.instance);
final dataResetServiceProvider = Provider<DataResetService>(
  (ref) => DataResetService(
    punches: ref.watch(punchRepositoryProvider),
    workDays: ref.watch(workDayRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
  ),
);

final profileProvider = StreamProvider<ProfileSettingsModel>((ref) => ref.watch(settingsRepositoryProvider).watchProfile());
final remindersProvider = StreamProvider<List<ReminderConfig>>((ref) => ref.watch(reminderRepositoryProvider).watchAll());

final daySummaryProvider = FutureProvider.family<WorkDaySummary, DateTime>((ref, date) async {
  final punches = await ref.watch(punchRepositoryProvider).listDay(date);
  final metadata = await ref.watch(workDayRepositoryProvider).getDay(date);
  return ref.watch(workHoursCalculatorProvider).calculate(date, punches, metadata);
});

final monthSummaryProvider = FutureProvider.family<MonthSummary, DateTime>((ref, date) async {
  final year = date.year;
  final month = date.month;
  final punches = await ref.watch(punchRepositoryProvider).watchMonth(year, month).first;
  final metadata = await ref.watch(workDayRepositoryProvider).watchMonth(year, month).first;
  final punchGroups = <String, List<Punch>>{};
  for (final punch in punches) {
    punchGroups.putIfAbsent(punch.localDate, () => <Punch>[]).add(punch);
  }
  final metaByDay = {for (final item in metadata) item.localDate: item};
  final keys = <String>{...punchGroups.keys, ...metaByDay.keys}.toList()..sort();
  final calculator = ref.watch(workHoursCalculatorProvider);
  final days = <WorkDaySummary>[];
  for (final key in keys) {
    final local = parseLocalDate(key);
    days.add(
      calculator.calculate(
        local,
        punchGroups[key] ?? const <Punch>[],
        metaByDay[key] ?? WorkDayMetadata(localDate: key),
      ),
    );
  }
  return MonthSummary(year: year, month: month, days: days);
});

