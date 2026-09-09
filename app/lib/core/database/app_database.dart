import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('PunchRow')
class Punches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get localDate => text()();
  IntColumn get occurredAtUtcMs => integer()();
  IntColumn get utcOffsetMin => integer()();
  TextColumn get kind => text()();
  BoolColumn get isEdited => boolean().withDefault(const Constant(false))();
  IntColumn get deletedAtUtcMs => integer().nullable()();
  IntColumn get createdAtUtcMs => integer()();
  IntColumn get updatedAtUtcMs => integer()();

  @override
  List<Set<Column<Object>>>? get uniqueKeys => null;
}

@DataClassName('WorkDayRow')
class WorkDays extends Table {
  TextColumn get localDate => text()();
  BoolColumn get includeInTimesheet => boolean().withDefault(const Constant(true))();
  TextColumn get activity => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAtUtcMs => integer()();
  IntColumn get updatedAtUtcMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {localDate};
}

@DataClassName('PunchAuditRow')
class PunchAudit extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get punchId => integer().references(Punches, #id)();
  TextColumn get action => text()();
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text().nullable()();
  IntColumn get changedAtUtcMs => integer()();
}

@DataClassName('ProfileSettingsRow')
class ProfileSettings extends Table {
  IntColumn get id => integer()();
  TextColumn get employeeName => text()();
  TextColumn get jobTitle => text()();
  TextColumn get workMode => text()();
  TextColumn get defaultActivity => text()();
  IntColumn get updatedAtUtcMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ReminderRow')
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  IntColumn get weekdaysMask => integer()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

@DriftDatabase(tables: [Punches, WorkDays, PunchAudit, ProfileSettings, Reminders])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX idx_punches_local_date_time '
            'ON punches(local_date, occurred_at_utc_ms)',
          );
          await customStatement(
            'CREATE INDEX idx_punch_audit_punch '
            'ON punch_audit(punch_id, changed_at_utc_ms)',
          );
        },
        onUpgrade: (m, from, to) async {
          if (from != to) {
            throw StateError('Migration não implementada: $from -> $to');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final directory = await getApplicationSupportDirectory();
      final file = File(p.join(directory.path, 'horafolio.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
