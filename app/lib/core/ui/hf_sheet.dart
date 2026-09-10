import 'package:flutter/material.dart';

import '../design/hf_tokens.dart';

/// Abre uma folha inferior no formato do OktaPonto.
///
/// Detalhe e edição vivem aqui em vez de em diálogos: a folha nasce do
/// conteúdo que a originou, cabe em uma mão e aceita conteúdo alto sem virar
/// uma caixa apertada no meio da tela.
Future<T?> showHfSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: HfSize.contentMaxWidth + 40),
    builder: builder,
  );
}

/// Estrutura interna de uma folha: cabeçalho fixo, corpo rolável e um rodapé
/// opcional que não some quando o teclado abre.
class HfSheetScaffold extends StatelessWidget {
  const HfSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    // A folha nunca passa de ~88% da altura: mantém o contexto de origem
    // visível e sinaliza que é uma camada, não outra tela.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HfSpace.xl,
                HfSpace.xs,
                HfSpace.md,
                HfSpace.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle != null) ...[
                    Text(
                      subtitle!.toUpperCase(),
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: HfSpace.xs),
                  ],
                  Text(title, style: theme.textTheme.headlineSmall),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  HfSpace.xl,
                  0,
                  HfSpace.xl,
                  HfSpace.xl,
                ),
                child: child,
              ),
            ),
            if (footer != null)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  HfSpace.xl,
                  HfSpace.md,
                  HfSpace.xl,
                  HfSpace.lg,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}
