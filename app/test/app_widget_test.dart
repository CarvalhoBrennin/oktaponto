import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horafolio/app.dart';
import 'package:horafolio/core/database/app_database.dart';
import 'package:horafolio/providers/app_providers.dart';

void main() {
  testWidgets('critical navigation surfaces are reachable', (tester) async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const HoraFolioApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hoje'), findsWidgets);
    expect(find.text('Registrar entrada'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.history).last);
    await tester.pumpAndSettle();
    expect(find.text('Histórico'), findsWidgets);
    await tester.tap(find.byIcon(Icons.calendar_month).last);
    await tester.pumpAndSettle();
    expect(find.text('Fechamento do mês'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings).last);
    await tester.pumpAndSettle();
    expect(find.text('Perfil do timesheet'), findsOneWidget);
  });
}
