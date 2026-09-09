import '../../../core/database/app_database.dart';
import '../../../core/files/file_service.dart';

/// Explicit destructive use case used by Settings.
///
/// SQLite tables are cleared in one database transaction. Filesystem exports
/// are then removed. The caller is responsible for cancelling OS reminders and
/// invalidating presentation providers after this operation succeeds.
final class DataResetService {
  const DataResetService({
    required this.database,
    required this.files,
  });

  final AppDatabase database;
  final FileService files;

  Future<void> clearAll() async {
    // Remove generated copies first. If filesystem cleanup cannot complete, the
    // authoritative SQLite data is left intact and the caller can retry; this
    // avoids reporting a reset while sensitive exports are still present.
    await files.clearExports();
    await database.transaction(() async {
      await database.delete(database.punchAudit).go();
      await database.delete(database.punches).go();
      await database.delete(database.workDays).go();
      await database.delete(database.profileSettings).go();
      await database.delete(database.reminders).go();
    });
  }
}
