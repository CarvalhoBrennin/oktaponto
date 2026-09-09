import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/time/time_utils.dart';
import '../../reminders/domain/reminder.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';

PunchKind _kindFromDb(String value) {
  switch (value) {
    case 'in':
      return PunchKind.in_;
    case 'out':
      return PunchKind.out;
  }
  throw StateError('Punch kind inválido no banco: $value');
}

String _kindToDb(PunchKind value) => value == PunchKind.in_ ? 'in' : 'out';

Punch _mapPunch(PunchRow row) => Punch(
      id: row.id,
      occurredAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row.occurredAtUtcMs,
        isUtc: true,
      ),
      localDate: row.localDate,
      utcOffsetMinutes: row.utcOffsetMin,
      kind: _kindFromDb(row.kind),
      isEdited: row.isEdited,
    );

Map<String, Object?> _punchJson(PunchRow row) => <String, Object?>{
      'id': row.id,
      'local_date': row.localDate,
      'occurred_at_utc_ms': row.occurredAtUtcMs,
      'utc_offset_min': row.utcOffsetMin,
      'kind': row.kind,
      'is_edited': row.isEdited,
      'deleted_at_utc_ms': row.deletedAtUtcMs,
      'created_at_utc_ms': row.createdAtUtcMs,
      'updated_at_utc_ms': row.updatedAtUtcMs,
    };

final class DriftPunchRepository implements PunchRepository {
  DriftPunchRepository(this.db);

  final AppDatabase db;

  Selectable<PunchRow> _activeDayQuery(String key) {
    return (db.select(db.punches)
          ..where((row) => row.localDate.equals(key) & row.deletedAtUtcMs.isNull())
          ..orderBy([(row) => OrderingTerm.asc(row.occurredAtUtcMs)]));
  }

  @override
  Stream<List<Punch>> watchDay(DateTime localDate) => _activeDayQuery(localDateKey(localDate))
      .watch()
      .map((rows) => rows.map(_mapPunch).toList(growable: false));

  @override
  Stream<List<Punch>> watchMonth(int year, int month) {
    final start = localDateKey(DateTime(year, month));
    final end = localDateKey(DateTime(year, month + 1));
    final query = db.select(db.punches)
      ..where(
        (row) =>
            row.deletedAtUtcMs.isNull() &
            row.localDate.isBiggerOrEqualValue(start) &
            row.localDate.isSmallerThanValue(end),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.localDate),
        (row) => OrderingTerm.asc(row.occurredAtUtcMs),
      ]);
    return query.watch().map((rows) => rows.map(_mapPunch).toList(growable: false));
  }

  @override
  Future<List<Punch>> listDay(DateTime localDate) async {
    final rows = await _activeDayQuery(localDateKey(localDate)).get();
    return rows.map(_mapPunch).toList(growable: false);
  }

  @override
  Future<Punch> insert(PunchDraft draft) async {
    return db.transaction(() async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db.into(db.workDays).insert(
            WorkDaysCompanion.insert(
              localDate: draft.localDate,
              createdAtUtcMs: now,
              updatedAtUtcMs: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      final id = await db.into(db.punches).insert(
            PunchesCompanion.insert(
              localDate: draft.localDate,
              occurredAtUtcMs: draft.occurredAtUtc.toUtc().millisecondsSinceEpoch,
              utcOffsetMin: draft.utcOffsetMinutes,
              kind: _kindToDb(draft.kind),
              isEdited: Value(draft.isEdited),
              createdAtUtcMs: now,
              updatedAtUtcMs: now,
            ),
          );
      final row = await (db.select(db.punches)..where((item) => item.id.equals(id))).getSingle();
      await db.into(db.punchAudit).insert(
            PunchAuditCompanion.insert(
              punchId: id,
              action: 'insert',
              afterJson: Value(jsonEncode(_punchJson(row))),
              changedAtUtcMs: now,
            ),
          );
      return _mapPunch(row);
    });
  }

  @override
  Future<void> update(PunchEdit edit) async {
    await db.transaction(() async {
      final before = await (db.select(db.punches)..where((row) => row.id.equals(edit.id))).getSingle();
      if (before.deletedAtUtcMs != null) {
        throw StateError('Não é possível editar uma batida excluída.');
      }
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await (db.update(db.punches)..where((row) => row.id.equals(edit.id))).write(
        PunchesCompanion(
          localDate: Value(edit.localDate),
          occurredAtUtcMs: Value(edit.occurredAtUtc.toUtc().millisecondsSinceEpoch),
          utcOffsetMin: Value(edit.utcOffsetMinutes),
          kind: Value(_kindToDb(edit.kind)),
          isEdited: const Value(true),
          updatedAtUtcMs: Value(now),
        ),
      );
      final after = await (db.select(db.punches)..where((row) => row.id.equals(edit.id))).getSingle();
      await db.into(db.punchAudit).insert(
            PunchAuditCompanion.insert(
              punchId: edit.id,
              action: 'update',
              beforeJson: Value(jsonEncode(_punchJson(before))),
              afterJson: Value(jsonEncode(_punchJson(after))),
              changedAtUtcMs: now,
            ),
          );
    });
  }

  @override
  Future<void> softDelete(int punchId) async {
    await db.transaction(() async {
      final before = await (db.select(db.punches)..where((row) => row.id.equals(punchId))).getSingle();
      if (before.deletedAtUtcMs != null) {
        return;
      }
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await (db.update(db.punches)..where((row) => row.id.equals(punchId))).write(
        PunchesCompanion(
          deletedAtUtcMs: Value(now),
          updatedAtUtcMs: Value(now),
          isEdited: const Value(true),
        ),
      );
      final after = await (db.select(db.punches)..where((row) => row.id.equals(punchId))).getSingle();
      await db.into(db.punchAudit).insert(
            PunchAuditCompanion.insert(
              punchId: punchId,
              action: 'delete',
              beforeJson: Value(jsonEncode(_punchJson(before))),
              afterJson: Value(jsonEncode(_punchJson(after))),
              changedAtUtcMs: now,
            ),
          );
    });
  }

  @override
  Future<void> clearAll() => db.transaction(() async {
        await db.delete(db.punchAudit).go();
        await db.delete(db.punches).go();
      });
}

final class DriftWorkDayRepository implements WorkDayRepository {
  DriftWorkDayRepository(this.db);
  final AppDatabase db;

  WorkDayMetadata _map(WorkDayRow row) => WorkDayMetadata(
        localDate: row.localDate,
        includeInTimesheet: row.includeInTimesheet,
        activity: row.activity,
        note: row.note,
      );

  @override
  Stream<WorkDayMetadata> watchDay(DateTime localDate) {
    final key = localDateKey(localDate);
    final query = db.select(db.workDays)..where((row) => row.localDate.equals(key));
    return query.watchSingleOrNull().map(
          (row) => row == null ? WorkDayMetadata(localDate: key) : _map(row),
        );
  }

  @override
  Stream<List<WorkDayMetadata>> watchMonth(int year, int month) {
    final start = localDateKey(DateTime(year, month));
    final end = localDateKey(DateTime(year, month + 1));
    final query = db.select(db.workDays)
      ..where((row) => row.localDate.isBiggerOrEqualValue(start) & row.localDate.isSmallerThanValue(end))
      ..orderBy([(row) => OrderingTerm.asc(row.localDate)]);
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  @override
  Future<WorkDayMetadata> getDay(DateTime localDate) async {
    final key = localDateKey(localDate);
    final query = db.select(db.workDays)..where((row) => row.localDate.equals(key));
    final row = await query.getSingleOrNull();
    return row == null ? WorkDayMetadata(localDate: key) : _map(row);
  }

  @override
  Future<void> upsert(WorkDayMetadata metadata) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final existing = await (db.select(db.workDays)..where((row) => row.localDate.equals(metadata.localDate))).getSingleOrNull();
    if (existing == null) {
      await db.into(db.workDays).insert(
            WorkDaysCompanion.insert(
              localDate: metadata.localDate,
              includeInTimesheet: Value(metadata.includeInTimesheet),
              activity: Value(metadata.activity),
              note: Value(metadata.note),
              createdAtUtcMs: now,
              updatedAtUtcMs: now,
            ),
          );
      return;
    }
    await (db.update(db.workDays)..where((row) => row.localDate.equals(metadata.localDate))).write(
      WorkDaysCompanion(
        includeInTimesheet: Value(metadata.includeInTimesheet),
        activity: Value(metadata.activity),
        note: Value(metadata.note),
        updatedAtUtcMs: Value(now),
      ),
    );
  }

  @override
  Future<void> clearAll() => db.delete(db.workDays).go();
}

final class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this.db);
  final AppDatabase db;

  static const _default = ProfileSettingsModel();

  ProfileSettingsModel _map(ProfileSettingsRow row) => ProfileSettingsModel(
        employeeName: row.employeeName,
        jobTitle: row.jobTitle,
        workMode: row.workMode,
        defaultActivity: row.defaultActivity,
      );

  @override
  Stream<ProfileSettingsModel> watchProfile() {
    final query = db.select(db.profileSettings)..where((row) => row.id.equals(1));
    return query.watchSingleOrNull().map((row) => row == null ? _default : _map(row));
  }

  @override
  Future<ProfileSettingsModel> getProfile() async {
    final query = db.select(db.profileSettings)..where((row) => row.id.equals(1));
    final row = await query.getSingleOrNull();
    return row == null ? _default : _map(row);
  }

  @override
  Future<void> saveProfile(ProfileSettingsModel profile) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.into(db.profileSettings).insertOnConflictUpdate(
          ProfileSettingsCompanion.insert(
            id: const Value(1),
            employeeName: profile.employeeName,
            jobTitle: profile.jobTitle,
            workMode: profile.workMode,
            defaultActivity: profile.defaultActivity,
            updatedAtUtcMs: now,
          ),
        );
  }

  @override
  Future<void> clearAll() => db.delete(db.profileSettings).go();
}

final class DriftReminderRepository implements ReminderRepository {
  DriftReminderRepository(this.db);
  final AppDatabase db;

  ReminderConfig _map(ReminderRow row) => ReminderConfig(
        id: row.id,
        label: row.label,
        hour: row.hour,
        minute: row.minute,
        weekdaysMask: row.weekdaysMask,
        enabled: row.enabled,
      );

  @override
  Stream<List<ReminderConfig>> watchAll() =>
      (db.select(db.reminders)..orderBy([(row) => OrderingTerm.asc(row.hour), (row) => OrderingTerm.asc(row.minute)]))
          .watch()
          .map((rows) => rows.map(_map).toList(growable: false));

  @override
  Future<List<ReminderConfig>> listAll() async {
    final rows = await (db.select(db.reminders)
          ..orderBy([(row) => OrderingTerm.asc(row.hour), (row) => OrderingTerm.asc(row.minute)]))
        .get();
    return rows.map(_map).toList(growable: false);
  }

  @override
  Future<int> save(ReminderConfig reminder) async {
    if (reminder.hour < 0 || reminder.hour > 23 || reminder.minute < 0 || reminder.minute > 59) {
      throw ArgumentError('Horário de lembrete inválido.');
    }
    if (reminder.id <= 0) {
      return db.into(db.reminders).insert(
            RemindersCompanion.insert(
              label: reminder.label,
              hour: reminder.hour,
              minute: reminder.minute,
              weekdaysMask: reminder.weekdaysMask,
              enabled: Value(reminder.enabled),
            ),
          );
    }
    await (db.update(db.reminders)..where((row) => row.id.equals(reminder.id))).write(
      RemindersCompanion(
        label: Value(reminder.label),
        hour: Value(reminder.hour),
        minute: Value(reminder.minute),
        weekdaysMask: Value(reminder.weekdaysMask),
        enabled: Value(reminder.enabled),
      ),
    );
    return reminder.id;
  }

  @override
  Future<void> delete(int id) => (db.delete(db.reminders)..where((row) => row.id.equals(id))).go();

  @override
  Future<void> clearAll() => db.delete(db.reminders).go();
}
