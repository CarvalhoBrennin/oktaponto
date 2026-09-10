import 'package:flutter/material.dart';

import '../../../../core/design/hf_semantics.dart';
import '../../../../core/design/hf_tokens.dart';
import '../../../../core/time/time_utils.dart';

/// Abertura do fechamento mensal: o total domina, o resto é contexto.
///
/// A resposta às duas primeiras perguntas do usuário — quanto trabalhei e
/// quantos dias entram — precisa caber em uma olhada, sem tabela e sem cartão.
class MonthHeadline extends StatelessWidget {
  const MonthHeadline({
    super.key,
    required this.month,
    required this.totalMinutes,
    required this.includedDays,
    required this.pendingCount,
  });

  final DateTime month;
  final int totalMinutes;
  final int includedDays;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthYearTitlePt(month).toUpperCase(),
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: HfSpace.sm),
        TweenAnimationBuilder<double>(
          duration: HfMotion.slow,
          curve: HfMotion.enter,
          tween: Tween<double>(end: 1),
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: Text(
            minutesToCompactHm(totalMinutes),
            style: theme.textTheme.displayLarge,
          ),
        ),
        const SizedBox(height: HfSpace.xs),
        Text(
          'Horas elegíveis para o timesheet',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: HfSpace.lg),
        Row(
          children: [
            _Metric(
              icon: Icons.event_available_outlined,
              role: hf.done,
              value: '$includedDays',
              label: includedDays == 1 ? 'dia incluído' : 'dias incluídos',
            ),
            const SizedBox(width: HfSpace.huge),
            _Metric(
              icon: pendingCount == 0
                  ? Icons.check_rounded
                  : Icons.priority_high_rounded,
              role: pendingCount == 0 ? hf.done : hf.attention,
              value: pendingCount == 0 ? 'Nenhuma' : '$pendingCount',
              label: pendingCount == 1 ? 'pendência' : 'pendências',
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.role,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final HfRole role;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: role.foreground),
          const SizedBox(width: HfSpace.sm),
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(text: ' $label'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
