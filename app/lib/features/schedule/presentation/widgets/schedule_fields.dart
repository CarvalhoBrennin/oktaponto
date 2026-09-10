import 'package:flutter/material.dart';

import '../../../../core/design/hf_semantics.dart';
import '../../../../core/design/hf_tokens.dart';
import '../../domain/work_schedule.dart';

/// Conversões entre o minuto-do-dia do domínio e o [TimeOfDay] da interface.
TimeOfDay timeOfDayFromMinutes(int minuteOfDay) =>
    TimeOfDay(hour: (minuteOfDay ~/ 60) % 24, minute: minuteOfDay % 60);

int minutesFromTimeOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

String formatMinuteOfDay(int minuteOfDay) {
  final hours = (minuteOfDay ~/ 60) % 24;
  final minutes = minuteOfDay % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
}

/// Duração em horas e minutos por extenso: `8h`, `8h30`, `45min`.
String formatDuration(int minutes) {
  if (minutes < 60) return '${minutes}min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0
      ? '${hours}h'
      : '${hours}h${rest.toString().padLeft(2, '0')}';
}

/// Linha de horário: rótulo à esquerda, hora grande e tocável à direita.
class ScheduleTimeField extends StatelessWidget {
  const ScheduleTimeField({
    super.key,
    required this.label,
    required this.minuteOfDay,
    required this.onChanged,
    this.helpText,
  });

  final String label;
  final int minuteOfDay;
  final ValueChanged<int> onChanged;
  final String? helpText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$label, ${formatMinuteOfDay(minuteOfDay)}',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: HfRadius.medium,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: timeOfDayFromMinutes(minuteOfDay),
              helpText: (helpText ?? label).toUpperCase(),
              confirmText: 'Confirmar',
              cancelText: 'Cancelar',
            );
            if (picked != null) onChanged(minutesFromTimeOfDay(picked));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: HfSpace.md),
            child: Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                Text(
                  formatMinuteOfDay(minuteOfDay),
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(width: HfSpace.sm),
                Icon(
                  Icons.edit_outlined,
                  size: 18,
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

/// Ajuste de duração em passos de 15 minutos.
///
/// Um seletor de horário para "quanto dura" faria o usuário calcular; aqui ele
/// só empurra para mais ou para menos.
class ScheduleDurationField extends StatelessWidget {
  const ScheduleDurationField({
    super.key,
    required this.label,
    required this.minutes,
    required this.onChanged,
    this.step = 15,
    this.min = 0,
    this.max = 8 * 60,
  });

  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;
  final int step;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrease = minutes - step >= min;
    final canIncrease = minutes + step <= max;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HfSpace.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          IconButton(
            onPressed: canDecrease ? () => onChanged(minutes - step) : null,
            icon: const Icon(Icons.remove_rounded),
            tooltip: 'Diminuir',
          ),
          Semantics(
            liveRegion: true,
            child: SizedBox(
              width: 76,
              child: Text(
                formatDuration(minutes),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          IconButton(
            onPressed: canIncrease ? () => onChanged(minutes + step) : null,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Aumentar',
          ),
        ],
      ),
    );
  }
}

/// Escolha entre intervalo com hora marcada e intervalo livre.
class BreakModeField extends StatelessWidget {
  const BreakModeField({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final BreakMode mode;
  final ValueChanged<BreakMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<BreakMode>(
          segments: const [
            ButtonSegment(
              value: BreakMode.fixed,
              label: Text('Hora marcada'),
              icon: Icon(Icons.schedule_outlined),
            ),
            ButtonSegment(
              value: BreakMode.flexible,
              label: Text('Livre'),
              icon: Icon(Icons.timelapse_outlined),
            ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) onChanged(selection.first);
          },
        ),
        const SizedBox(height: HfSpace.sm),
        Text(
          mode == BreakMode.fixed
              ? 'Seu intervalo é sempre no mesmo horário. O OktaPonto avisa na '
                    'hora de sair e na hora de voltar.'
              : 'Você sai para o intervalo quando dá. O OktaPonto começa a '
                    'contar na batida e avisa quando o tempo combinado fecha.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Dias em que a jornada acontece.
class WeekdayPickerField extends StatelessWidget {
  const WeekdayPickerField({
    super.key,
    required this.mask,
    required this.onChanged,
  });

  final int mask;
  final ValueChanged<int> onChanged;

  static const _labels = <String>[
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: HfSpace.sm,
      runSpacing: HfSpace.sm,
      children: [
        for (var day = 1; day <= 7; day++)
          FilterChip(
            label: Text(_labels[day - 1]),
            selected: (mask & (1 << (day - 1))) != 0,
            onSelected: (selected) => onChanged(
              selected ? mask | (1 << (day - 1)) : mask & ~(1 << (day - 1)),
            ),
          ),
      ],
    );
  }
}

/// Resumo da jornada em uma frase, para confirmar antes de salvar.
class ScheduleSummary extends StatelessWidget {
  const ScheduleSummary({super.key, required this.schedule});

  final WorkSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hf = context.hf;
    final breakText = schedule.breakMode == BreakMode.fixed
        ? '${formatDuration(schedule.breakMinutes)} de intervalo às '
              '${formatMinuteOfDay(schedule.breakStartMinuteOfDay)}'
        : '${formatDuration(schedule.breakMinutes)} de intervalo livre';

    return Container(
      padding: const EdgeInsets.all(HfSpace.xl),
      decoration: BoxDecoration(
        color: hf.working.container,
        borderRadius: HfRadius.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUA JORNADA',
            style: theme.textTheme.labelSmall?.copyWith(
              color: hf.working.onContainer,
            ),
          ),
          const SizedBox(height: HfSpace.sm),
          Text(
            formatDuration(schedule.targetMinutes),
            style: theme.textTheme.displayMedium?.copyWith(
              color: hf.working.onContainer,
            ),
          ),
          const SizedBox(height: HfSpace.xs),
          Text(
            'por dia, das ${formatMinuteOfDay(schedule.startMinuteOfDay)} '
            'às ${formatMinuteOfDay(schedule.endMinuteOfDay)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hf.working.onContainer,
            ),
          ),
          Text(
            breakText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hf.working.onContainer,
            ),
          ),
        ],
      ),
    );
  }
}
