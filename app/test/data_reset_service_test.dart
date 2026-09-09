import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/core/database/app_database.dart';
import 'package:horafolio/core/files/file_service.dart';
import 'package:horafolio/features/settings/domain/data_reset_service.dart';

void main() {
  test('clearAll removes SQLite data and generated exports', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('horafolio_reset_');
    final files = FileService(documentsRootPath: root.path);
    addTearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO profile_settings(id, employee_name, job_title, work_mode, default_activity, updated_at_utc_ms) VALUES (1, 'A', 'B', 'C', 'D', $now)",
    );
    final exportDir = await files.exportDirectory();
    final export = File('$exportDir/test.xlsx');
    await export.writeAsBytes([1, 2, 3]);

    await DataResetService(database: db, files: files).clearAll();

    final profileCount = await db
        .customSelect('SELECT COUNT(*) AS c FROM profile_settings')
        .getSingle();
    expect(profileCount.read<int>('c'), 0);
    expect(await export.exists(), isFalse);
  });
}
