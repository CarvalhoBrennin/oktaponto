import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/core/database/app_database.dart';
import 'package:horafolio/features/punch/domain/models.dart';
import 'package:horafolio/providers/app_providers.dart';

void main() {
  test('register -> edit -> close -> export end-to-end application flow', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final times = <DateTime>[
      DateTime(2026, 9, 1, 8),
      DateTime(2026, 9, 1, 12),
      DateTime(2026, 9, 1, 13),
      DateTime(2026, 9, 1, 17),
    ];
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(Clock(() => times.removeAt(0))),
      ],
    );
    final temp = await Directory.systemTemp.createTemp('horafolio-integration-');
    addTearDown(() async {
      container.dispose();
      await db.close();
      await temp.delete(recursive: true);
    });

    final service = container.read(punchServiceProvider);
    for (var index = 0; index < 4; index++) {
      await service.registerNextPunch(DateTime(2026, 9, 1));
    }
    await container.read(workDayRepositoryProvider).upsert(
          const WorkDayMetadata(
            localDate: '2026-09-01',
            activity: 'Entrega integrada',
          ),
        );

    final original = await container
        .read(punchRepositoryProvider)
        .listDay(DateTime(2026, 9, 1));
    await service.editPunch(
      PunchEdit(
        id: original.first.id,
        localDate: '2026-09-01',
        occurredAtUtc: DateTime.utc(2026, 9, 1, 7, 30),
        utcOffsetMinutes: 0,
        kind: PunchKind.in_,
      ),
    );

    container.invalidate(monthSummaryProvider(DateTime(2026, 9)));
    final month = await container
        .read(monthSummaryProvider(DateTime(2026, 9)).future);
    expect(month.totalMinutes, 510);
    expect(
      container.read(monthlyValidatorProvider).validate(month).isValid,
      isTrue,
    );

    final result = await container.read(timesheetExporterProvider).exportMonth(
          month,
          const ProfileSettingsModel(
            employeeName: 'Pessoa Teste',
            jobTitle: 'Analista',
            workMode: 'Remoto',
            defaultActivity: 'Atividade padrão',
          ),
          temp.path,
        );
    final output = File(result.outputPath);
    expect(await output.exists(), isTrue);
    expect(await output.length(), greaterThan(0));
    expect(result.totalMinutes, 510);
  });
}
