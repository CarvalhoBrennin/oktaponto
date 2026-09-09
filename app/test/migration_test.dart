import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/core/database/app_database.dart';

void main() {
  test('schema v1 creates authoritative tables, indexes, FK and guards', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 1);

    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    final tables = rows.map((row) => row.read<String>('name')).toSet();
    expect(
      tables,
      containsAll(<String>{
        'punch_audit',
        'punches',
        'reminders',
        'profile_settings',
        'work_days',
      }),
    );
    expect(tables, isNot(contains('worked_minutes')));

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%' ORDER BY name",
        )
        .get();
    final names = indexes.map((row) => row.read<String>('name')).toSet();
    expect(
      names,
      containsAll(['idx_punches_local_date_time', 'idx_punch_audit_punch']),
    );

    final foreignKeys = await db
        .customSelect('PRAGMA foreign_key_list(punches)')
        .get();
    expect(
      foreignKeys.any(
        (row) =>
            row.read<String>('table') == 'work_days' &&
            row.read<String>('from') == 'local_date' &&
            row.read<String>('to') == 'local_date',
      ),
      isTrue,
    );

    final triggers = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' ORDER BY name",
        )
        .get();
    final triggerNames = triggers
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(
      triggerNames,
      containsAll([
        'trg_punch_kind_insert',
        'trg_punch_kind_update',
        'trg_reminder_bounds_insert',
        'trg_reminder_bounds_update',
      ]),
    );

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO work_days(local_date, include_in_timesheet, created_at_utc_ms, updated_at_utc_ms) VALUES ('2026-09-01', 1, $now, $now)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO punches(local_date, occurred_at_utc_ms, utc_offset_min, kind, is_edited, created_at_utc_ms, updated_at_utc_ms) VALUES ('2026-09-01', $now, 0, 'invalid', 0, $now, $now)",
      ),
      throwsA(anything),
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO reminders(label, hour, minute, weekdays_mask, enabled) VALUES ('x', 99, 0, 1, 1)",
      ),
      throwsA(anything),
    );
  });
}
