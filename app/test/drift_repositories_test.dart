import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/core/database/app_database.dart';
import 'package:horafolio/features/punch/data/drift_repositories.dart';
import 'package:horafolio/features/punch/domain/models.dart';
import 'package:horafolio/features/reminders/domain/reminder.dart';

void main() {
  late AppDatabase db;
  late DriftPunchRepository punches;
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    punches = DriftPunchRepository(db);
  });
  tearDown(() => db.close());

  test('schema version starts at 1', () => expect(db.schemaVersion, 1));

  test('insert survives a new repository instance on same database', () async {
    await punches.insert(PunchDraft(localDate: '2026-09-01', occurredAtUtc: DateTime.utc(2026, 9, 1, 8), utcOffsetMinutes: -180, kind: PunchKind.in_));
    final reopenedRepo = DriftPunchRepository(db);
    expect(await reopenedRepo.listDay(DateTime(2026, 9, 1)), hasLength(1));
  });


  test('file-backed database survives close and reopen', () async {
    final dir = await Directory.systemTemp.createTemp('horafolio_db_');
    final path = '${dir.path}/horafolio.sqlite';
    final firstDb = AppDatabase(executor: NativeDatabase(File(path)));
    final firstRepo = DriftPunchRepository(firstDb);
    await firstRepo.insert(
      PunchDraft(
        localDate: '2026-09-01',
        occurredAtUtc: DateTime.utc(2026, 9, 1, 8),
        utcOffsetMinutes: 0,
        kind: PunchKind.in_,
      ),
    );
    await firstDb.close();

    final secondDb = AppDatabase(executor: NativeDatabase(File(path)));
    final secondRepo = DriftPunchRepository(secondDb);
    expect(await secondRepo.listDay(DateTime(2026, 9, 1)), hasLength(1));
    await secondDb.close();
    await dir.delete(recursive: true);
  });

  test('reminder repository rejects blank labels and invalid weekday masks', () async {
    final reminders = DriftReminderRepository(db);
    await expectLater(
      reminders.save(
        const ReminderConfig(
          id: 0,
          label: ' ',
          hour: 8,
          minute: 0,
          weekdaysMask: 31,
          enabled: true,
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      reminders.save(
        const ReminderConfig(
          id: 0,
          label: 'Ponto',
          hour: 8,
          minute: 0,
          weekdaysMask: 0,
          enabled: true,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('soft delete removes punch from calculation queries and writes audit', () async {
    final created = await punches.insert(PunchDraft(localDate: '2026-09-01', occurredAtUtc: DateTime.utc(2026, 9, 1, 8), utcOffsetMinutes: -180, kind: PunchKind.in_));
    await punches.softDelete(created.id);
    expect(await punches.listDay(DateTime(2026, 9, 1)), isEmpty);
    final audits = await db.select(db.punchAudit).get();
    expect(audits.map((a) => a.action), containsAll(['insert', 'delete']));
  });

  test('manual edit creates audit and changes timestamp', () async {
    final created = await punches.insert(PunchDraft(localDate: '2026-09-01', occurredAtUtc: DateTime.utc(2026, 9, 1, 8), utcOffsetMinutes: -180, kind: PunchKind.in_));
    await punches.update(PunchEdit(id: created.id, localDate: '2026-09-01', occurredAtUtc: DateTime.utc(2026, 9, 1, 9), utcOffsetMinutes: -180, kind: PunchKind.in_));
    final edited = (await punches.listDay(DateTime(2026, 9, 1))).single;
    expect(edited.occurredAtUtc.hour, 9);
    expect(edited.isEdited, isTrue);
    expect((await db.select(db.punchAudit).get()).map((a) => a.action), contains('update'));
  });
}
