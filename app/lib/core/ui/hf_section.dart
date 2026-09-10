import 'package:flutter/material.dart';

import '../design/hf_tokens.dart';

/// Cabeçalho de seção: sobrelinha opcional, título e uma ação à direita.
///
/// Substitui o hábito de embrulhar cada bloco em um `Card` — o agrupamento
/// passa a vir de tipografia e espaçamento.
class HfSectionHeader extends StatelessWidget {
  const HfSectionHeader({
    super.key,
    required this.title,
    this.overline,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: HfSpace.md),
  });

  final String title;
  final String? overline;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[
                  Text(overline!.toUpperCase(), style: text.labelSmall),
                  const SizedBox(height: HfSpace.xs),
                ],
                Text(title, style: text.titleMedium),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: HfSpace.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Bloco de conteúdo com respiro vertical padronizado.
class HfSection extends StatelessWidget {
  const HfSection({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.top = HfSpace.huge,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) HfSectionHeader(title: title!, trailing: trailing),
          child,
        ],
      ),
    );
  }
}
