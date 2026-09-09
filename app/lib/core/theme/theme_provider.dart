import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'horafolio_theme_mode';

/// Ordem imutável para persistência: 0=system, 1=light, 2=dark
int _encode(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 0,
  ThemeMode.light => 1,
  ThemeMode.dark => 2,
};

ThemeMode _decode(int? raw) => switch (raw) {
  1 => ThemeMode.light,
  2 => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// Controla ThemeMode com persistência leve.
/// - Default: system (segue OS), mas o app inicializa em system;
///   o tema escuro fica disponível 100% via toggle em Configurações.
/// - Persistência via SharedPreferences (NSUserDefaults/SharedPrefs/windows).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  SharedPreferences? _prefs;
  bool _disposed = false;
  bool _hydrated = false;

  @override
  ThemeMode build() {
    ref.onDispose(() => _disposed = true);
    if (!_hydrated) {
      _hydrated = true;
      // Hidrata fora do build para não violar pureza; microtask garante
      // que o primeiro frame com 'system' já foi entregue.
      Future.microtask(_hydrate);
    }
    return ThemeMode.system;
  }

  Future<void> _hydrate() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (_disposed) return;
      final saved = _decode(_prefs!.getInt(_kThemeModeKey));
      if (saved != state) {
        if (_disposed) return;
        state = saved;
      }
    } catch (error, stackTrace) {
      // Hidratação best-effort; loga para diagnóstico sem quebrar UI.
      // ignore: avoid_print
      debugPrint('ThemeMode hydrate falhou: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setInt(_kThemeModeKey, _encode(mode));
    } catch (error, stackTrace) {
      debugPrint('ThemeMode persist falhou: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Atalho para alternância clara: escuro -> claro -> sistema -> escuro ...
  Future<void> cycle() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setMode(next);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Helper para UI: label humano.
String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Automático (sistema)',
  ThemeMode.light => 'Claro',
  ThemeMode.dark => 'Escuro',
};

IconData themeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.system => Icons.brightness_auto_outlined,
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
};
