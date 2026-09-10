import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/core/database/app_database.dart';
import 'package:oktaponto/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oktaponto/features/punch/domain/models.dart';
import 'package:oktaponto/features/punch/presentation/today_screen.dart';
import 'package:oktaponto/features/schedule/domain/work_schedule.dart';
import 'package:oktaponto/providers/app_providers.dart';

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
  ProviderContainer container, {
  ThemeData? theme,
  Size size = const Size(430, 860),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      // Usa o tema real do app: o golden precisa provar o design system que
      // está em produção, não um ThemeData genérico de teste.
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme ?? AppTheme.light,
        home: const TodayScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Cenários cobertos pelos goldens. Cada um é um estado real da jornada.
final _entry = (DateTime.utc(2026, 9, 1, 8), PunchKind.in_);
final _breakStart = (DateTime.utc(2026, 9, 1, 12), PunchKind.out);
final _breakEnd = (DateTime.utc(2026, 9, 1, 13), PunchKind.in_);
final _exit = (DateTime.utc(2026, 9, 1, 17), PunchKind.out);

void main() {
  // A apresentação inicial não entra nos goldens da tela Hoje; sem jornada
  // configurada o anel mede os quatro registros, que é o estado base.
  setUp(
    () => SharedPreferences.setMockInitialValues(<String, Object>{
      'oktaponto_onboarding_seen': true,
    }),
  );

  test('golden baselines are versioned', () {
    for (final path in <String>[
      'test/goldens/ui/today_empty.png',
      'test/goldens/ui/today_working.png',
      'test/goldens/ui/today_break.png',
      'test/goldens/ui/today_complete.png',
      'test/goldens/ui/today_complete_dark.png',
      'test/goldens/ui/today_goal.png',
    ]) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason:
            'Baseline ausente: $path. Execute tool/update_goldens.sh em '
            'Flutter 3.47.2 e versione o PNG.',
      );
    }
  });

  Future<void> golden(
    WidgetTester tester,
    List<(DateTime, PunchKind)> punches,
    String file, {
    ThemeData? theme,
  }) async {
    final fixture = await _containerWithPunches(punches);
    addTearDown(() async {
      fixture.container.dispose();
      await fixture.database.close();
    });
    await _pumpToday(tester, fixture.container, theme: theme);
    await expectLater(
      find.byType(TodayScreen),
      matchesGoldenFile('goldens/ui/$file.png'),
    );
  }

  testWidgets('golden: Hoje sem registros', (tester) async {
    await golden(tester, const [], 'today_empty');
  });

  testWidgets('golden: Hoje trabalhando', (tester) async {
    await golden(tester, [_entry], 'today_working');
  });

  testWidgets('golden: Hoje em intervalo', (tester) async {
    await golden(tester, [_entry, _breakStart], 'today_break');
  });

  testWidgets('golden: Hoje concluído', (tester) async {
    await golden(tester, [
      _entry,
      _breakStart,
      _breakEnd,
      _exit,
    ], 'today_complete');
  });

  testWidgets('golden: Hoje concluído no tema escuro', (tester) async {
    await golden(
      tester,
      [_entry, _breakStart, _breakEnd, _exit],
      'today_complete_dark',
      theme: AppTheme.dark,
    );
  });

  testWidgets('golden: Hoje com meta de jornada', (tester) async {
    // Jornada 08:00–17:00 com 1h de intervalo: meta de 8h. Com meta, o anel
    // deixa de contar os quatro registros e passa a medir o progresso.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'oktaponto_onboarding_seen': true,
      'oktaponto_work_schedule': jsonEncode(
        WorkSchedule.defaults
            .copyWith(
              startMinuteOfDay: 8 * 60,
              endMinuteOfDay: 17 * 60,
              breakMinutes: 60,
            )
            .toJson(),
      ),
    });
    // Meia jornada cumprida, em intervalo: o anel fica pela metade.
    await golden(tester, [_entry, _breakStart], 'today_goal');
  });

  testWidgets('a tela Hoje cabe em 360px sem overflow', (tester) async {
    final fixture = await _containerWithPunches([_entry, _breakStart]);
    addTearDown(() async {
      fixture.container.dispose();
      await fixture.database.close();
    });
    await _pumpToday(tester, fixture.container, size: const Size(360, 690));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tela Hoje suporta fonte ampliada sem overflow', (
    tester,
  ) async {
    final fixture = await _containerWithPunches([_entry]);
    addTearDown(() async {
      fixture.container.dispose();
      await fixture.database.close();
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.5,
            maxScaleFactor: 1.5,
            child: child!,
          ),
          home: const TodayScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
