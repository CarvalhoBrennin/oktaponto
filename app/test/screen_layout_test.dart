import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/app.dart';
import 'package:oktaponto/core/database/app_database.dart';
import 'package:oktaponto/core/theme/app_theme.dart';
import 'package:oktaponto/features/history/presentation/history_screen.dart';
import 'package:oktaponto/features/month_close/presentation/month_screen.dart';
import 'package:oktaponto/features/punch/domain/models.dart';
import 'package:oktaponto/features/settings/presentation/settings_screen.dart';
import 'package:oktaponto/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mês coberto pela massa de teste.
final _fixtureMonth = DateTime(2026, 9);

/// Larguras reais de aparelho que o OktaPonto precisa atender.
const _compact = Size(360, 690); // Android de entrada
const _regular = Size(430, 860); // iPhone Pro Max

/// Um mês com um dia completo, um dia incompleto e um dia fora do timesheet —
/// o suficiente para exercitar calendário, lista, pendências e exportação.
Future<({ProviderContainer container, AppDatabase database})> _fixture() async {
  final db = AppDatabase(executor: NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(Clock.fixed(DateTime(2026, 9, 9, 18))),
    ],
  );
  final punches = container.read(punchRepositoryProvider);
  Future<void> add(String date, int hour, PunchKind kind) => punches
      .insert(
        PunchDraft(
          localDate: date,
          occurredAtUtc: DateTime.utc(
            2026,
            9,
            int.parse(date.split('-').last),
            hour,
          ),
          utcOffsetMinutes: 0,
          kind: kind,
        ),
      )
      .then((_) {});

  await add('2026-09-07', 8, PunchKind.in_);
  await add('2026-09-07', 12, PunchKind.out);
  await add('2026-09-07', 13, PunchKind.in_);
  await add('2026-09-07', 17, PunchKind.out);
  // Dia incompleto: vira pendência no fechamento.
  await add('2026-09-08', 9, PunchKind.in_);
  return (container: container, database: db);
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen, {
  required Size size,
  required ThemeData theme,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // `monthSummaryProvider` consome um stream do drift, que só emite no loop de
  // eventos real. Se a tela assinasse o provider primeiro, a assinatura
  // nasceria sob o relógio falso do teste e nunca completaria — então o valor
  // é resolvido antes, e a assinatura é mantida aberta para não ser descartada.
  late final ProviderSubscription<AsyncValue<MonthSummary>> subscription;
  await tester.runAsync(() async {
    subscription = container.listen(
      monthSummaryProvider(_fixtureMonth),
      (_, _) {},
    );
    await container.read(monthSummaryProvider(_fixtureMonth).future);
  });
  addTearDown(subscription.close);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues(<String, Object>{
      'oktaponto_onboarding_seen': true,
    }),
  );

  final screens = <String, Widget Function()>{
    'Histórico': HistoryScreen.new,
    'Fechamento': MonthScreen.new,
    'Configurações': SettingsScreen.new,
  };

  for (final entry in screens.entries) {
    for (final theme in <(String, ThemeData)>[
      ('claro', AppTheme.light),
      ('escuro', AppTheme.dark),
    ]) {
      for (final size in <(String, Size)>[
        ('360px', _compact),
        ('430px', _regular),
      ]) {
        testWidgets(
          '${entry.key} no tema ${theme.$1} em ${size.$1} não estoura o layout',
          (tester) async {
            final fixture = await _fixture();
            addTearDown(() async {
              fixture.container.dispose();
              await fixture.database.close();
            });
            await _pump(
              tester,
              fixture.container,
              entry.value(),
              size: size.$2,
              theme: theme.$2,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 50));
          },
        );
      }
    }

    testWidgets('${entry.key} sobrevive a fonte 1,5x em 360px', (tester) async {
      final fixture = await _fixture();
      addTearDown(() async {
        fixture.container.dispose();
        await fixture.database.close();
      });
      await _pump(
        tester,
        fixture.container,
        entry.value(),
        size: _compact,
        theme: AppTheme.light,
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  }

  testWidgets('o fechamento aponta o dia incompleto como pendência', (
    tester,
  ) async {
    final fixture = await _fixture();
    addTearDown(() async {
      fixture.container.dispose();
      await fixture.database.close();
    });
    await _pump(
      tester,
      fixture.container,
      const MonthScreen(),
      size: _regular,
      theme: AppTheme.light,
    );
    expect(find.text('1 dia precisa de atenção'), findsOneWidget);
    // A pendência diz o que falta naquele dia, não "dia inválido".
    expect(
      find.text('Falta a saída para o intervalo, o retorno e a saída final.'),
      findsOneWidget,
    );
    // A exportação continua bloqueada enquanto houver pendência.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Gerar timesheet'),
    );
    expect(button.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('o histórico lista os dias registrados do mês', (tester) async {
    final fixture = await _fixture();
    addTearDown(() async {
      fixture.container.dispose();
      await fixture.database.close();
    });
    await _pump(
      tester,
      fixture.container,
      const HistoryScreen(),
      size: _regular,
      theme: AppTheme.light,
    );
    expect(find.text('2 dias registrados'), findsOneWidget);
    expect(find.text('1 a revisar'), findsOneWidget);
    expect(find.text('Completo'), findsOneWidget);
    expect(find.text('Incompleto'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('em tela larga a navegação vai para a lateral', (tester) async {
    final fixture = await _fixture();
    addTearDown(() async {
      fixture.container.dispose();
      await fixture.database.close();
    });
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late final ProviderSubscription<AsyncValue<MonthSummary>> subscription;
    await tester.runAsync(() async {
      subscription = fixture.container.listen(
        monthSummaryProvider(_fixtureMonth),
        (_, _) {},
      );
      await fixture.container.read(monthSummaryProvider(_fixtureMonth).future);
    });
    addTearDown(subscription.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: const OktaPontoApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Trocar de destino pela lateral continua funcionando.
    await tester.tap(find.byIcon(Icons.description_outlined).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Fechamento'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
