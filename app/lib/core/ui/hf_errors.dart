import 'package:flutter/foundation.dart';

/// Traduz uma falha em algo que o usuário possa agir a respeito.
///
/// As regras do domínio já lançam `StateError` com mensagens escritas para
/// pessoas ("O dia já possui quatro batidas..."), então essas passam direto.
/// Qualquer outra falha vira uma frase curta e honesta, e o detalhe técnico
/// fica no log — nunca na interface.
String friendlyError(Object error) {
  if (error is StateError) return error.message;
  debugPrint('OktaPonto: falha não tratada na interface: $error');
  return 'Algo deu errado e a ação não foi concluída. Tente novamente.';
}

/// Executa um "puxar para atualizar" sem deixar a falha escapar.
///
/// `RefreshIndicator` repassa qualquer exceção do callback para o framework,
/// o que vira erro não tratado. A tela já mostra o estado de erro do provider,
/// então aqui basta registrar e devolver o controle ao indicador.
Future<void> guardedRefresh(Future<void> Function() refresh) async {
  try {
    await refresh();
  } catch (error, stackTrace) {
    debugPrint('OktaPonto: falha ao recarregar: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
