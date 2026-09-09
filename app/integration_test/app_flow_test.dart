import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/app.dart';
import 'package:horafolio/core/database/app_database.dart';
import 'package:horafolio/features/punch/domain/models.dart';
import 'package:horafolio/providers/app_providers.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI: register four punches -> history -> export', (tester) async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    var current = DateTime(2026, 9, 1, 7);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(Clock(() => current)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    await container.read(settingsRepositoryProvider).saveProfile(
          const ProfileSettingsModel(
            employeeName: 'Pessoa Teste',
            jobTitle: 'Analista',
            workMode: 'Remoto',
            defaultActivity: 'Atividade padrão',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HoraFolioApp(),
      ),
    );
    await tester.pumpAndSettle();

    for (final time in <DateTime>[
      DateTime(2026, 9, 1, 8),
      DateTime(2026, 9, 1, 12),
      DateTime(2026, 9, 1, 13),
      DateTime(2026, 9, 1, 17),
    ]) {
      current = time;
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
    }
    expect(find.text('Completo'), findsOneWidget);
    expect(find.text('Total: 08:00'), findsOneWidget);

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 batidas'), findsOneWidget);

    await tester.tap(find.text('Mês'));
    await tester.pumpAndSettle();
    expect(find.text('Mês consistente e pronto para exportar.'), findsOneWidget);
    await tester.tap(find.text('Gerar timesheet XLSX'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Arquivo gerado'), findsOneWidget);
  });
}
