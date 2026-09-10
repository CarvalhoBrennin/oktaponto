import 'package:flutter/material.dart';

import '../../../../core/design/hf_semantics.dart';
import '../../../../core/design/hf_tokens.dart';
import '../../../../core/time/time_utils.dart';
import '../../../punch/domain/models.dart';
import '../../../punch/presentation/workday_visuals.dart';

/// A forma do mês em uma olhada.
///
/// Cada célula é um dia: o número em si carrega o estado, e uma marca abaixo
/// dele repete a informação em forma — traço para completo, meio-círculo para
/// incompleto, alerta para revisar. Estado nunca depende só de cor.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.days,
    required this.today,
    required this.onSelect,
  });

  final DateTime month;
  final Map<int, WorkDaySummary> days;
  final DateTime today;
  final void Function(DateTime date) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Semana começa na segunda-feira, como no resto do app.
    final leading = first.weekday - DateTime.monday;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();
    // Mesma escala usada pela célula, para que as linhas vazias do início e do
    // fim do mês acompanhem a altura das demais.
    final cellScale = (MediaQuery.textScalerOf(context).scale(13) / 13).clamp(
      1.0,
      1.8,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Text(
                  weekdayShortPt(first.add(Duration(days: i - leading))),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: HfSpace.sm),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final dayNumber = row * 7 + column - leading + 1;
                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return SizedBox(height: 46 * cellScale);
                      }
                      final date = DateTime(month.year, month.month, dayNumber);
                      return _CalendarCell(
                        date: date,
                        day: days[dayNumber],
                        isToday: dateOnly(today) == date,
                        onTap: () => onSelect(date),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.date,
    required this.day,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final WorkDaySummary? day;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final summary = day;
    final hasRecords = summary != null && summary.punches.isNotEmpty;
    final visual = hasRecords ? visualForDay(hf, summary) : null;

    // A célula acompanha o tamanho de fonte do sistema: com a escala grande,
    // o círculo cresce junto em vez de deixar o número vazar por fora dele.
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final capped = scale.clamp(1.0, 1.8);
    final disc = 28 * capped;
    final cell = 46 * capped;

    return Semantics(
      button: true,
      label: hasRecords
          ? '${dayAndMonthPt(date)}, ${visual!.label}, '
                '${minutesToCompactHm(summary.workedMinutes)}'
          : '${dayAndMonthPt(date)}, sem registro',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: HfRadius.small,
          child: SizedBox(
            height: cell,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: disc,
                  height: disc,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasRecords ? visual!.role.container : null,
                    shape: BoxShape.circle,
                    border: isToday
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                  // Última rede de segurança: qualquer fonte cujos dígitos
                  // fiquem largos demais é reduzida em vez de vazar do disco.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${date.day}',
                      maxLines: 1,
                      textScaler: TextScaler.noScaling,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 13 * capped,
                        color: hasRecords
                            ? visual!.role.onContainer
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: hasRecords || isToday
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                // Marca redundante à cor, para quem não a distingue.
                SizedBox(
                  height: 6,
                  child: hasRecords
                      ? Icon(
                          visual!.icon,
                          size: 9,
                          color: visual.role.foreground,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
