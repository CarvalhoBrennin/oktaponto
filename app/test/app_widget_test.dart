import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/app.dart';
import 'package:oktaponto/core/database/app_database.dart';
import 'package:oktaponto/core/theme/theme_provider.dart';
import 'package:oktaponto/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('critical navigation surfaces are reachable', (tester) async {
    // Sem esta marca o app abre a apresentação inicial em vez do shell.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'oktaponto_onboarding_seen': true,
    });
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          themeModeProvider.overrideWith(
            () => _FixedThemeNotifier(ThemeMode.light),
          ),
        ],
        child: const OktaPontoApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Hoje'), findsWidgets);
    expect(find.text('Registrar entrada'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Histórico'), findsWidgets);

    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Banco de horas'), findsWidgets);

    await tester.tap(find.byIcon(Icons.description_outlined).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Fechamento'), findsWidgets);

    // Configurações saiu da barra inferior e virou ação da barra superior.
    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('SEUS DADOS NO TIMESHEET'), findsOneWidget);
    expect(find.text('APARÊNCIA'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Desmonta a árvore dentro do teste e deixa os streams do drift fecharem
    // seus timers antes da verificação de invariantes do binding.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}

class _FixedThemeNotifier extends ThemeModeNotifier {
  _FixedThemeNotifier(this._mode);
  final ThemeMode _mode;
  @override
  ThemeMode build() => _mode;
}
