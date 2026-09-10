import 'package:flutter/material.dart';

import '../../../../core/design/hf_semantics.dart';
import '../../../../core/design/hf_tokens.dart';
import '../../../../core/time/time_utils.dart';
import '../../domain/weekly_distribution.dart';

/// Distribuição semanal — barras e nada mais.
///
/// Sem eixos, sem grade, sem tooltip: este é um aplicativo pessoal, e a única
/// pergunta que a visualização precisa responder é se alguma semana destoou.
class WeeklyHoursChart extends StatelessWidget {
  const WeeklyHoursChart({super.key, required this.weeks});

  final List<WeekBucket> weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final peak = weeks.fold<int>(
      0,
      (max, w) => w.minutes > max ? w.minutes : max,
    );
    if (peak == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final week in weeks)
          Padding(
            padding: const EdgeInsets.only(bottom: HfSpace.md),
            child: Semantics(
              label:
                  'Semana ${week.index + 1}: '
                  '${minutesToCompactHm(week.minutes)}',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        'Semana ${week.index + 1}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: HfSpace.md),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        duration: HfMotion.slow,
                        curve: HfMotion.enter,
                        tween: Tween<double>(end: week.minutes / peak),
                        builder: (context, value, _) => ClipRRect(
                          borderRadius: HfRadius.pill,
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 10,
                            backgroundColor: hf.track,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              hf.working.foreground,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: HfSpace.md),
                    SizedBox(
                      width: 54,
                      child: Text(
                        minutesToCompactHm(week.minutes),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
