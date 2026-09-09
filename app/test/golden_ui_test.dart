import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/core/database/app_database.dart';
import 'package:horafolio/features/punch/domain/models.dart';
import 'package:horafolio/features/punch/presentation/today_screen.dart';
import 'package:horafolio/providers/app_providers.dart';

Future<({ProviderContainer container, AppDatabase database})>
_containerWithPunches(List<(DateTime, PunchKind)> punches) async {
  final db = AppDatabase(executor: NativeDatabase.memory());
  final fixedNow = DateTime(2026, 9, 1, 18);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(Clock.fixed(fixedNow)),
    ],
  );
  for (final entry in punches) {
    await container
        .read(punchRepositoryProvider)
        .insert(
          PunchDraft(
            localDate: '2026-09-01',
            occurredAtUtc: entry.$1.toUtc(),
            utcOffsetMinutes: 0,
            kind: entry.$2,
          ),
        );
  }
  return (container: container, database: db);
}

Future<void> _pumpToday(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 860));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF1F3864),
          useMaterial3: true,
        ),
        home: const TodayScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('golden baselines are versioned', () {
    for (final path in <String>[
      'test/goldens/ui/today_empty.png',
      'test/goldens/ui/today_working.png',
      'test/goldens/ui/today_complete.png',
    ]) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason:
            'Baseline ausente: $path. Execute tool/update_goldens.sh em Flutter 3.47.2 e versione o PNG.',
      );
    }
  });
  testWidgets('golden: Hoje vazio', (tester) async {
    final fixture = await _containerWithPunches(const []);
    addTearDown(() async {
      fixture.container.dispose();
      await fixture.database.close();
    });
    await _pumpToday(tester, fixture.container);
    await expectLater(
      find.byType(TodayScreen),
      matchesGoldenFile('goldens/ui/today_empty.png'),
    );
  });

  testWidgets('golden: Hoje trabalhando', (tester) async {
    final fixture = await _containerWithPunches([
      (DateTime.utc(2026, 9, 1, 8), PunchKind.in_),
    ]);
    addTearDown(() async {
      fixture.container.dispose();
      await fixture.database.close();
    });
    await _pumpToday(tester, fixture.container);
    await expectLater(
      find.byType(TodayScreen),
      matchesGoldenFile('goldens/ui/today_working.png'),
    );
  });

  testWidgets('golden: Hoje completo', (tester) async {
    final fixture = await _containerWithPunches([
      (DateTime.utc(2026, 9, 1, 8), PunchKind.in_),
      (DateTime.utc(2026, 9, 1, 12), PunchKind.out),
      (DateTime.utc(2026, 9, 1, 13), PunchKind.in_),
      (DateTime.utc(2026, 9, 1, 17), PunchKind.out),
    ]);
    addTearDown(() async {
      fixture.container.dispose();
      await fixture.database.close();
    });
    await _pumpToday(tester, fixture.container);
    await expectLater(
      find.byType(TodayScreen),
      matchesGoldenFile('goldens/ui/today_complete.png'),
    );
  });
}
