import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/core/database/app_database.dart';
import 'package:oktaponto/core/theme/app_theme.dart';
import 'package:oktaponto/features/bank_hours/presentation/bank_hours_screen.dart';
import 'package:oktaponto/features/punch/domain/models.dart';
import 'package:oktaponto/features/schedule/domain/work_schedule.dart';
import 'package:oktaponto/features/schedule/presentation/schedule_provider.dart';
import 'package:oktaponto/providers/app_providers.dart';

final _month = DateTime(2026, 9);

void main() {
  testWidgets('displays collected overtime in the bank tab', (tester) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(
          Clock.fixed(DateTime(2026, 9, 9, 18)),
        ),
        scheduleSetupProvider.overrideWith(() => _FixedScheduleNotifier()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    final punches = container.read(punchRepositoryProvider);
    await punches.insert(
      PunchDraft(
        localDate: '2026-09-09',
        occurredAtUtc: DateTime.utc(2026, 9, 9, 8),
        utcOffsetMinutes: 0,
        kind: PunchKind.in_,
      ),
    );
    await punches.insert(
      PunchDraft(
        localDate: '2026-09-09',
        occurredAtUtc: DateTime.utc(2026, 9, 9, 12),
        utcOffsetMinutes: 0,
        kind: PunchKind.out,
      ),
    );
    await punches.insert(
      PunchDraft(
        localDate: '2026-09-09',
        occurredAtUtc: DateTime.utc(2026, 9, 9, 13),
        utcOffsetMinutes: 0,
        kind: PunchKind.in_,
      ),
    );
    await punches.insert(
      PunchDraft(
        localDate: '2026-09-09',
        occurredAtUtc: DateTime.utc(2026, 9, 9, 18),
        utcOffsetMinutes: 0,
        kind: PunchKind.out,
      ),
    );

    await tester.runAsync(() async {
      await container.read(scheduleSetupProvider.future);
      await container.read(monthSummaryProvider(_month).future);
    });
    await tester.binding.setSurfaceSize(const Size(430, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const BankHoursScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Banco de horas'), findsOneWidget);
    expect(find.text('1 dia com hora extra'), findsOneWidget);
    expect(find.text('+01h00'), findsWidgets);
    expect(find.text('09h00 trabalhadas · 08h00 de meta'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}

class _FixedScheduleNotifier extends ScheduleSetupNotifier {
  @override
  Future<ScheduleSetup> build() async => const ScheduleSetup(
    onboardingSeen: true,
    schedule: WorkSchedule.defaults,
  );
}
