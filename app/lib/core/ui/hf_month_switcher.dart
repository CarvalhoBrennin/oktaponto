import 'package:flutter/material.dart';

import '../design/hf_tokens.dart';
import '../time/time_utils.dart';

/// Navegação entre meses, idêntica no Histórico e no Fechamento.
///
/// O mês é o eixo dessas duas telas; ter o mesmo controle nos dois lugares faz
/// a troca virar um gesto aprendido uma vez só.
class HfMonthSwitcher extends StatelessWidget {
  const HfMonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
  });

  final DateTime month;
  final void Function(int delta) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: () => onChanged(-1),
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Mês anterior',
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: AnimatedSwitcher(
              duration: HfMotion.fast,
              child: Text(
                monthYearTitlePt(month),
                key: ValueKey<String>('${month.year}-${month.month}'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(1),
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Próximo mês',
        ),
      ],
    );
  }
}
