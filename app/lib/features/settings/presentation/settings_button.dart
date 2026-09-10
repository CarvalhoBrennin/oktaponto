import 'package:flutter/material.dart';

import 'settings_screen.dart';

/// Ponto de entrada das Configurações a partir de qualquer tela principal.
///
/// Configurações saiu da barra inferior: perfil, lembretes e aparência são
/// ajustes ocasionais e estavam ocupando um quarto da navegação diária. A
/// barra ficou com a narrativa do produto — agora, passado, fechamento — e
/// isto vira uma ação na barra superior, presente nas três telas.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.tune_rounded),
      tooltip: 'Configurações',
      onPressed: () => openSettings(context),
    );
  }
}

Future<void> openSettings(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
}
