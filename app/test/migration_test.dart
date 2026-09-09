import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/core/database/app_database.dart';

void main() {
  test('schema v1 creates all authoritative tables and indexes', () async {
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
    expect(names, contains('idx_punches_local_date_time'));
    expect(names, contains('idx_punch_audit_punch'));

    final foreignKeys = await db.customSelect('PRAGMA foreign_key_list(punches)').get();
    expect(
      foreignKeys.any(
        (row) =>
            row.read<String>('table') == 'work_days' &&
            row.read<String>('from') == 'local_date' &&
            row.read<String>('to') == 'local_date',
      ),
      isTrue,
    );

  });
}
