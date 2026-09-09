import '../../punch/domain/repositories.dart';

/// Explicit destructive use case used by Settings. Keeping this operation out
/// of widgets preserves the presentation -> application/domain -> data flow.
final class DataResetService {
  const DataResetService({
    required this.punches,
    required this.workDays,
    required this.settings,
    required this.reminders,
  });

  final PunchRepository punches;
  final WorkDayRepository workDays;
  final SettingsRepository settings;
  final ReminderRepository reminders;

  Future<void> clearAll() async {
    await punches.clearAll();
    await workDays.clearAll();
    await settings.clearAll();
    await reminders.clearAll();
  }
}
