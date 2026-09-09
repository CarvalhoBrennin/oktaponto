import 'package:flutter/material.dart';

import 'features/history/presentation/history_screen.dart';
import 'features/month_close/presentation/month_screen.dart';
import 'features/punch/presentation/today_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

class HoraFolioApp extends StatelessWidget {
  const HoraFolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HoraFólio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F3864),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  static const _pages = <Widget>[
    TodayScreen(),
    HistoryScreen(),
    MonthScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: _pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.access_time), label: 'Hoje'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Mês'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Configurações'),
        ],
      ),
    );
  }
}
