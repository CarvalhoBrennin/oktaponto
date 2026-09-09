import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/core/database/app_database.dart';
import 'package:horafolio/features/punch/domain/models.dart';
import 'package:horafolio/providers/app_providers.dart';

void main() {
  test(
    'day summary provider derives hours from punches instead of persisted totals',
    () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final repo = container.read(punchRepositoryProvider);
      await repo.insert(
        PunchDraft(
          localDate: '2026-09-01',
          occurredAtUtc: DateTime.utc(2026, 9, 1, 8),
          utcOffsetMinutes: 0,
          kind: PunchKind.in_,
        ),
      );
      await repo.insert(
        PunchDraft(
          localDate: '2026-09-01',
          occurredAtUtc: DateTime.utc(2026, 9, 1, 12),
          utcOffsetMinutes: 0,
          kind: PunchKind.out,
        ),
      );
      await repo.insert(
        PunchDraft(
          localDate: '2026-09-01',
          occurredAtUtc: DateTime.utc(2026, 9, 1, 13),
          utcOffsetMinutes: 0,
          kind: PunchKind.in_,
        ),
      );
      await repo.insert(
        PunchDraft(
          localDate: '2026-09-01',
          occurredAtUtc: DateTime.utc(2026, 9, 1, 17),
          utcOffsetMinutes: 0,
          kind: PunchKind.out,
        ),
      );
      final summary = await container.read(
        daySummaryProvider(DateTime(2026, 9, 1)).future,
      );
      expect(summary.workedMinutes, 480);
      expect(summary.status, WorkDayStatus.complete);
    },
  );
}
