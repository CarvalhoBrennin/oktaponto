import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/app.dart';
import 'package:oktaponto/core/database/app_database.dart';
import 'package:oktaponto/features/punch/domain/models.dart';
import 'package:oktaponto/providers/app_providers.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI: register four punches -> history -> export', (tester) async {
    // Sem esta marca o app abre a apresentação inicial em vez do shell.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'oktaponto_onboarding_seen': true,
    });
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

    await container
        .read(settingsRepositoryProvider)
        .saveProfile(
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
        child: const OktaPontoApp(),
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
    expect(find.text('Jornada concluída'), findsWidgets);
    expect(find.text('08h00'), findsWidgets);

    await tester.tap(find.text('Histórico').last);
    await tester.pumpAndSettle();
    expect(find.text('1 dia registrado'), findsOneWidget);
    expect(find.text('Completo'), findsWidgets);

    await tester.tap(find.text('Fechamento').last);
    await tester.pumpAndSettle();
    expect(find.text('Tudo pronto para fechar o mês.'), findsOneWidget);
    await tester.tap(find.text('Gerar timesheet'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Arquivo gerado'), findsOneWidget);
  });
}
