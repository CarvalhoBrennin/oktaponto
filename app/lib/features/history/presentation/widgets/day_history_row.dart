import 'package:flutter/material.dart';

import '../../../../core/design/hf_semantics.dart';
import '../../../../core/design/hf_tokens.dart';
import '../../../../core/time/time_utils.dart';
import '../../../punch/domain/models.dart';
import '../../../punch/presentation/workday_visuals.dart';

/// Uma linha por dia — não um cartão por dia.
///
/// Colunas fixas (data, estado, total) fazem a lista virar uma tabela leve que
/// se lê na vertical: dá para varrer trinta dias sem parar em cada bloco.
class DayHistoryRow extends StatelessWidget {
  const DayHistoryRow({super.key, required this.day, required this.onTap});

  final WorkDaySummary day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final visual = visualForDay(hf, day);
    final excluded = !day.includeInTimesheet;

    return Semantics(
      button: true,
      label:
          '${day.date.day} de ${weekdayPt(day.date)}, ${visual.label}, '
          '${minutesToCompactHm(day.workedMinutes)}'
          '${excluded ? ', fora do timesheet' : ''}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: HfRadius.small,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: HfSpace.md),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.date.day.toString().padLeft(2, '0'),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        weekdayShortPt(day.date),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: HfSpace.md),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        visual.icon,
                        size: 16,
                        color: visual.role.foreground,
                      ),
                      const SizedBox(width: HfSpace.sm - 2),
                      Flexible(
                        child: Text(
                          visual.label,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: visual.role.foreground,
                          ),
                        ),
                      ),
                      if (excluded) ...[
                        const SizedBox(width: HfSpace.sm),
                        Flexible(
                          child: Text(
                            '· fora do timesheet',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: HfSpace.md),
                Text(
                  minutesToCompactHm(day.workedMinutes),
                  style: theme.textTheme.titleMedium,
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
