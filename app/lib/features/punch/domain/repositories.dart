import '../../reminders/domain/reminder.dart';
import 'models.dart';

abstract interface class PunchRepository {
  Future<T> transaction<T>(Future<T> Function(PunchRepository repository) action);
  Stream<List<Punch>> watchDay(DateTime localDate);
  Stream<List<Punch>> watchMonth(int year, int month);
  Future<List<Punch>> listDay(DateTime localDate);
  Future<Punch> insert(PunchDraft draft);
  Future<void> update(PunchEdit edit);
  Future<void> softDelete(int punchId);
  Future<void> clearAll();
}

abstract interface class WorkDayRepository {
  Stream<WorkDayMetadata> watchDay(DateTime localDate);
  Stream<List<WorkDayMetadata>> watchMonth(int year, int month);
  Future<WorkDayMetadata> getDay(DateTime localDate);
  Future<void> upsert(WorkDayMetadata metadata);
  Future<void> clearAll();
}

abstract interface class SettingsRepository {
  Stream<ProfileSettingsModel> watchProfile();
  Future<ProfileSettingsModel> getProfile();
  Future<void> saveProfile(ProfileSettingsModel profile);
  Future<void> clearAll();
}

abstract interface class ReminderRepository {
  Stream<List<ReminderConfig>> watchAll();
  Future<List<ReminderConfig>> listAll();
  Future<int> save(ReminderConfig reminder);
  Future<void> delete(int id);
  Future<void> clearAll();
}
