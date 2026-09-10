import 'package:flutter/material.dart';

import '../design/hf_semantics.dart';
import '../design/hf_tokens.dart';

/// Selo de estado: sempre cor **e** ícone **e** texto.
///
/// Nenhum estado do OktaPonto é comunicado só por cor; este componente existe
/// para tornar isso a opção mais fácil em qualquer tela.
class HfStatusBadge extends StatelessWidget {
  const HfStatusBadge({
    super.key,
    required this.role,
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final HfRole role;
  final IconData icon;
  final String label;

  /// Versão reduzida usada dentro de linhas de lista.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: label,
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? HfSpace.sm : HfSpace.md,
          vertical: compact ? 3 : HfSpace.xs + 2,
        ),
        decoration: BoxDecoration(
          color: role.container,
          borderRadius: HfRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 13 : 15, color: role.onContainer),
            SizedBox(width: compact ? HfSpace.xs : HfSpace.sm - 2),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: (compact ? text.labelMedium : text.labelLarge)?.copyWith(
                  color: role.onContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 12 : 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
