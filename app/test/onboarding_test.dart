import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/app.dart';
import 'package:oktaponto/core/database/app_database.dart';
import 'package:oktaponto/core/theme/theme_provider.dart';
import 'package:oktaponto/features/onboarding/presentation/onboarding_screen.dart';
import 'package:oktaponto/features/schedule/data/work_schedule_store.dart';
import 'package:oktaponto/features/schedule/domain/work_schedule.dart';
import 'package:oktaponto/features/schedule/presentation/schedule_provider.dart';
import 'package:oktaponto/providers/app_providers.dart';

/// Store em memória.
///
/// Tira `SharedPreferences` do caminho: o canal de plataforma só resolve no
/// loop de eventos real, e um teste de widget que precise de `runAsync` para
/// abrir a primeira tela fica lento e frágil. O contrato real do
/// armazenamento é coberto em `work_schedule_store_test.dart`.
final class _FakeStore implements WorkScheduleStore {
  _FakeStore([this.setup = ScheduleSetup.initial]);

  ScheduleSetup setup;

  @override
  Future<ScheduleSetup> load() async => setup;

  @override
  Future<void> save(WorkSchedule schedule) async {
    setup = ScheduleSetup(
      onboardingSeen: setup.onboardingSeen,
      schedule: schedule,
    );
  }

  @override
  Future<void> markOnboardingSeen() async {
    setup = ScheduleSetup(onboardingSeen: true, schedule: setup.schedule);
  }

  @override
  Future<void> clear() async => setup = ScheduleSetup.initial;
}

({ProviderContainer container, AppDatabase database, _FakeStore store})
_fixture({ScheduleSetup setup = ScheduleSetup.initial}) {
  final db = AppDatabase(executor: NativeDatabase.memory());
  final store = _FakeStore(setup);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(Clock.fixed(DateTime(2026, 9, 9, 10))),
      themeModeProvider.overrideWith(() => _FixedTheme(ThemeMode.light)),
      workScheduleStoreProvider.overrideWithValue(store),
    ],
  );
  return (container: container, database: db, store: store);
}

Future<void> _pumpApp(WidgetTester tester, ProviderContainer container) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const OktaPontoApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Desmonta a árvore e descarta o container ainda dentro do teste.
///
/// Descartar o container só no `addTearDown` trava: os streams do drift
/// agendam um timer de duração zero ao fechar, e fora do relógio falso do
/// teste esse timer nunca roda.
Future<void> _teardown(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  container.dispose();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('primeira abertura cai na apresentação', (tester) async {
    final fixture = _fixture();
    addTearDown(() async => fixture.database.close());

    await _pumpApp(tester, fixture.container);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Bem-vindo ao OktaPonto'), findsOneWidget);
    // O shell só aparece depois de configurar ou pular.
    expect(find.byType(AppShell), findsNothing);

    await _teardown(tester, fixture.container);
  });

  testWidgets('quem já passou pela apresentação vai direto para Hoje', (
    tester,
  ) async {
    final fixture = _fixture(
      setup: const ScheduleSetup(onboardingSeen: true, schedule: null),
    );
    addTearDown(() async => fixture.database.close());

    await _pumpApp(tester, fixture.container);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Registrar entrada'), findsOneWidget);

    await _teardown(tester, fixture.container);
  });

  testWidgets('percorrer a apresentação grava a jornada e libera o app', (
    tester,
  ) async {
    final fixture = _fixture();
    addTearDown(() async => fixture.database.close());

    await _pumpApp(tester, fixture.container);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    // Boas-vindas → identidade → horários → intervalo → lembretes.
    for (var step = 0; step < 4; step++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Quer ser lembrado?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Começar a usar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final saved = fixture.store.setup;
    expect(saved.onboardingSeen, isTrue);
    // Horários padrão preservados. Os lembretes ficam desligados porque o
    // ambiente de teste não tem o canal de notificações do aparelho — e é
    // justamente isso que não pode impedir a jornada de ser salva.
    expect(saved.schedule!.startMinuteOfDay, 9 * 60);
    expect(saved.schedule!.endMinuteOfDay, 18 * 60);
    expect(saved.schedule!.breakMinutes, 60);
    expect(saved.targetMinutes, 480);
    expect(find.byType(OnboardingScreen), findsNothing);

    await _teardown(tester, fixture.container);
  });

  testWidgets('pular a apresentação não inventa jornada nenhuma', (
    tester,
  ) async {
    final fixture = _fixture();
    addTearDown(() async => fixture.database.close());

    await _pumpApp(tester, fixture.container);
    await tester.tap(find.widgetWithText(TextButton, 'Configurar depois'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(fixture.store.setup.onboardingSeen, isTrue);
    expect(fixture.store.setup.schedule, isNull);
    // Sem jornada não há meta, e o herói volta a contar os quatro registros.
    expect(fixture.container.read(dailyTargetMinutesProvider), isNull);
    expect(find.byType(OnboardingScreen), findsNothing);

    await _teardown(tester, fixture.container);
  });

  testWidgets('jornada gravada vira meta do dia', (tester) async {
    final schedule = WorkSchedule.defaults.copyWith(
      startMinuteOfDay: 8 * 60,
      endMinuteOfDay: 17 * 60,
      breakMinutes: 60,
    );
    final fixture = _fixture(
      setup: ScheduleSetup(onboardingSeen: true, schedule: schedule),
    );
    addTearDown(() async => fixture.database.close());

    await _pumpApp(tester, fixture.container);
    expect(fixture.container.read(dailyTargetMinutesProvider), 480);
    // Antes da primeira batida o "faltam 08h00" seria só a jornada repetida.
    expect(find.textContaining('faltam'), findsNothing);

    await _teardown(tester, fixture.container);
  });
}

class _FixedTheme extends ThemeModeNotifier {
  _FixedTheme(this._mode);
  final ThemeMode _mode;
  @override
  ThemeMode build() => _mode;
}
