import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/hf_tokens.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/month_close/presentation/month_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/punch/presentation/today_screen.dart';
import 'features/schedule/presentation/schedule_provider.dart';

class OktaPontoApp extends ConsumerWidget {
  const OktaPontoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'OktaPonto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      themeAnimationDuration: HfMotion.base,
      themeAnimationCurve: HfMotion.standard,
      home: const _Entry(),
    );
  }
}

/// Decide entre a apresentação e o app propriamente dito.
///
/// A configuração inicial vem do armazenamento do aparelho, então há um
/// instante de carregamento: mostrar a tela Hoje e trocar para a apresentação
/// um frame depois seria pior do que segurar.
class _Entry extends ConsumerWidget {
  const _Entry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(scheduleSetupProvider);
    return AnimatedSwitcher(
      duration: HfMotion.base,
      child: switch (setup) {
        AsyncData(:final value) when value.needsOnboarding =>
          const OnboardingScreen(),
        AsyncData() => const AppShell(),
        // Preferência ilegível não pode travar o app: segue para o uso normal,
        // sem jornada configurada.
        AsyncError() => const AppShell(),
        _ => const Scaffold(body: SizedBox.shrink()),
      },
    );
  }
}

/// Destinos principais, na ordem da narrativa do produto:
/// o agora, o que já passou e o fechamento do mês.
enum _Destination {
  today('Hoje', Icons.schedule_outlined, Icons.schedule_rounded),
  history('Histórico', Icons.calendar_month_outlined, Icons.calendar_month),
  close('Fechamento', Icons.description_outlined, Icons.description);

  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  // IndexedStack preserva o estado de cada aba (mês selecionado, rolagem)
  // entre trocas — o usuário volta ao Histórico onde havia parado.
  static const _pages = <Widget>[TodayScreen(), HistoryScreen(), MonthScreen()];

  void _select(int value) => setState(() => _index = value);

  @override
  Widget build(BuildContext context) {
    final destinations = _Destination.values;
    final content = IndexedStack(index: _index, children: _pages);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Em telas largas a navegação vai para a lateral e o conteúdo ganha
        // uma coluna de leitura confortável, em vez de esticar até a borda.
        if (constraints.maxWidth >= HfSize.wideBreakpoint) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: HfSize.contentMaxWidth + HfSpace.section,
                      ),
                      child: content,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: content,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: [
              for (final destination in destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
