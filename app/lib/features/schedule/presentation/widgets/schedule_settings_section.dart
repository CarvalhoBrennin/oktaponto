import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hf_tokens.dart';
import '../../../../core/ui/hf_errors.dart';
import '../../../../core/ui/hf_notice.dart';
import '../../../../core/ui/hf_sheet.dart';
import '../../../../providers/app_providers.dart';
import '../../../reminders/presentation/reminder_hooks.dart';
import '../../../settings/presentation/widgets/settings_group.dart';
import '../../domain/work_schedule.dart';
import '../schedule_provider.dart';
import 'schedule_fields.dart';

/// Bloco "Minha jornada" das Configurações.
///
/// Mostra a jornada em vigor em uma linha e abre a edição completa em folha.
/// Quem pulou a apresentação vê aqui o convite para definir a jornada.
class ScheduleSettingsSection extends ConsumerWidget {
  const ScheduleSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final schedule = ref.watch(workScheduleProvider);

    return SettingsGroup(
      title: 'Minha jornada',
      description:
          'Define a meta do dia na tela Hoje e os horários em que o app avisa '
          'para bater o ponto.',
      children: [
        if (schedule == null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Você ainda não definiu sua jornada. Sem ela, o app não '
                'calcula a meta do dia nem manda lembretes automáticos.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: HfSpace.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _edit(context, ref, WorkSchedule.defaults),
                  icon: const Icon(Icons.schedule_outlined, size: 20),
                  label: const Text('Definir jornada'),
                ),
              ),
            ],
          )
        else
          _ScheduleSummaryRow(
            schedule: schedule,
            onTap: () => _edit(context, ref, schedule),
          ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    WorkSchedule initial,
  ) async {
    final result = await showHfSheet<WorkSchedule>(
      context: context,
      builder: (_) => _ScheduleSheet(initial: initial),
    );
    if (result == null) return;

    // Uma recusa de notificação — ou uma falha ao pedi-la — desliga só os
    // lembretes. A jornada configurada é salva de qualquer jeito.
    var schedule = result;
    var denied = false;
    if (schedule.remindersEnabled) {
      denied = !await _requestNotificationPermission(ref);
      if (denied) schedule = schedule.copyWith(remindersEnabled: false);
    }

    try {
      await ref.read(scheduleSetupProvider.notifier).save(schedule);
      await refreshRecurringReminders(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            denied
                ? 'Jornada salva, mas o aparelho não autorizou notificações.'
                : 'Jornada salva.',
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  Future<bool> _requestNotificationPermission(WidgetRef ref) async {
    try {
      return await ref.read(notificationServiceProvider).requestPermissions();
    } catch (error, stackTrace) {
      logReminderFailure(error, stackTrace);
      return false;
    }
  }
}

class _ScheduleSummaryRow extends StatelessWidget {
  const _ScheduleSummaryRow({required this.schedule, required this.onTap});

  final WorkSchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final breakText = schedule.breakMode == BreakMode.fixed
        ? 'intervalo às ${formatMinuteOfDay(schedule.breakStartMinuteOfDay)}'
        : 'intervalo livre';

    return InkWell(
      onTap: onTap,
      borderRadius: HfRadius.medium,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: HfSpace.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatMinuteOfDay(schedule.startMinuteOfDay)} às '
                    '${formatMinuteOfDay(schedule.endMinuteOfDay)}',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '${formatDuration(schedule.targetMinutes)} por dia · '
                    '${formatDuration(schedule.breakMinutes)} de $breakText',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    schedule.remindersEnabled
                        ? 'Lembretes ligados'
                        : 'Lembretes desligados',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.initial});

  final WorkSchedule initial;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late WorkSchedule _schedule = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = _schedule.problem;

    return HfSheetScaffold(
      title: 'Minha jornada',
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: HfSpace.md),
          Expanded(
            child: FilledButton(
              onPressed: problem == null
                  ? () => Navigator.pop(context, _schedule)
                  : null,
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScheduleTimeField(
            label: 'Entrada',
            minuteOfDay: _schedule.startMinuteOfDay,
            onChanged: (value) => setState(
              () => _schedule = _schedule.copyWith(startMinuteOfDay: value),
            ),
          ),
          const Divider(),
          ScheduleTimeField(
            label: 'Saída',
            minuteOfDay: _schedule.endMinuteOfDay,
            onChanged: (value) => setState(
              () => _schedule = _schedule.copyWith(endMinuteOfDay: value),
            ),
          ),
          const SizedBox(height: HfSpace.xxl),
          Text('INTERVALO', style: theme.textTheme.labelSmall),
          const SizedBox(height: HfSpace.md),
          BreakModeField(
            mode: _schedule.breakMode,
            onChanged: (mode) =>
                setState(() => _schedule = _schedule.copyWith(breakMode: mode)),
          ),
          const SizedBox(height: HfSpace.lg),
          ScheduleDurationField(
            label: 'Duração',
            minutes: _schedule.breakMinutes,
            onChanged: (value) => setState(
              () => _schedule = _schedule.copyWith(breakMinutes: value),
            ),
            max: 4 * 60,
          ),
          if (_schedule.breakMode == BreakMode.fixed) ...[
            const Divider(),
            ScheduleTimeField(
              label: 'Começa às',
              helpText: 'Início do intervalo',
              minuteOfDay: _schedule.breakStartMinuteOfDay,
              onChanged: (value) => setState(
                () => _schedule = _schedule.copyWith(
                  breakStartMinuteOfDay: value,
                ),
              ),
            ),
          ],
          const SizedBox(height: HfSpace.xxl),
          Text('LEMBRETES', style: theme.textTheme.labelSmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _schedule.remindersEnabled,
            onChanged: (value) => setState(
              () => _schedule = _schedule.copyWith(remindersEnabled: value),
            ),
            title: const Text('Avisar na hora de bater o ponto'),
          ),
          if (_schedule.remindersEnabled) ...[
            const SizedBox(height: HfSpace.md),
            WeekdayPickerField(
              mask: _schedule.weekdaysMask,
              onChanged: (mask) => setState(
                () => _schedule = _schedule.copyWith(weekdaysMask: mask),
              ),
            ),
            const SizedBox(height: HfSpace.md),
            ScheduleDurationField(
              label: 'Avisar antes',
              minutes: _schedule.leadMinutes,
              onChanged: (value) => setState(
                () => _schedule = _schedule.copyWith(leadMinutes: value),
              ),
              step: 5,
              max: 60,
            ),
          ],
          const SizedBox(height: HfSpace.xl),
          if (problem != null)
            HfNotice(tone: HfNoticeTone.attention, message: problem)
          else
            ScheduleSummary(schedule: _schedule),
        ],
      ),
    );
  }
}
