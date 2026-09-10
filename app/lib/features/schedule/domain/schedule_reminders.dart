import '../../punch/domain/models.dart';
import '../../punch/domain/workday_progress.dart';
import 'work_schedule.dart';

String _clock(int minuteOfDay) {
  final hours = (minuteOfDay ~/ 60) % 24;
  final minutes = minuteOfDay % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
}

/// Um aviso recorrente derivado da jornada configurada.
///
/// Não é um [ReminderConfig] do usuário: ele não é editável item a item e é
/// recalculado toda vez que a jornada muda. O `slot` mantém o identificador
/// estável entre reagendamentos.
final class ScheduleReminder {
  const ScheduleReminder({
    required this.slot,
    required this.minuteOfDay,
    required this.message,
  });

  /// Posição fixa do aviso na jornada (0 = entrada … 3 = saída final).
  final int slot;

  final int minuteOfDay;
  final String message;

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;
}

/// Os avisos recorrentes que a jornada gera.
///
/// Com intervalo fixo são quatro; com intervalo livre são dois, porque a saída
/// para o almoço não tem hora marcada e o retorno passa a ser avisado a partir
/// da batida real — ver [planBreakReminder].
List<ScheduleReminder> plannedReminders(WorkSchedule schedule) {
  if (!schedule.remindersEnabled || !schedule.isValid) return const [];

  // Avisar antes da hora só faz sentido dentro do próprio dia; um aviso que
  // cairia antes da meia-noite é encostado em 00:00.
  int lead(int minuteOfDay) {
    final shifted = minuteOfDay - schedule.leadMinutes;
    return shifted < 0 ? 0 : shifted;
  }

  final reminders = <ScheduleReminder>[
    ScheduleReminder(
      slot: 0,
      minuteOfDay: lead(schedule.startMinuteOfDay),
      message:
          'Sua jornada começa às ${_clock(schedule.startMinuteOfDay)}. '
          'Registre a entrada.',
    ),
  ];

  if (schedule.breakMode == BreakMode.fixed) {
    final breakEnd = schedule.breakStartMinuteOfDay + schedule.breakMinutes;
    reminders.addAll([
      ScheduleReminder(
        slot: 1,
        minuteOfDay: lead(schedule.breakStartMinuteOfDay),
        message:
            'Hora do intervalo (${_clock(schedule.breakStartMinuteOfDay)}). '
            'Registre a saída.',
      ),
      ScheduleReminder(
        slot: 2,
        minuteOfDay: lead(breakEnd),
        message:
            'O intervalo termina às ${_clock(breakEnd)}. Registre o retorno.',
      ),
    ]);
  }

  reminders.add(
    ScheduleReminder(
      slot: 3,
      minuteOfDay: lead(schedule.endMinuteOfDay),
      message:
          'Sua jornada termina às ${_clock(schedule.endMinuteOfDay)}. '
          'Registre a saída final.',
    ),
  );

  return List.unmodifiable(reminders);
}

/// Quando avisar que o intervalo em andamento acabou.
final class BreakReminderPlan {
  const BreakReminderPlan({required this.dueAt, required this.followUpAt});

  /// Instante em que o intervalo configurado se completa.
  final DateTime dueAt;

  /// Segunda e última insistência, caso o retorno ainda não tenha sido batido.
  final DateTime followUpAt;
}

/// Intervalo de teimosia entre o primeiro aviso e a única repetição.
const breakReminderFollowUp = Duration(minutes: 15);

/// Decide se existe um aviso de fim de intervalo a agendar para [day].
///
/// Só vale para o intervalo livre: no fixo o horário já é conhecido e vira
/// aviso recorrente. Retorna `null` quando não há intervalo em curso, quando a
/// jornada não está configurada ou quando o dia não é o de hoje — nesses casos
/// o chamador cancela qualquer aviso pendente.
BreakReminderPlan? planBreakReminder({
  required WorkDaySummary day,
  required WorkSchedule? schedule,
  required DateTime nowLocal,
}) {
  final current = schedule;
  if (current == null ||
      !current.isValid ||
      !current.remindersEnabled ||
      current.breakMode != BreakMode.flexible ||
      current.breakMinutes <= 0) {
    return null;
  }
  if (!current.includesWeekday(day.date.weekday)) return null;

  final progress = describeWorkday(day, nowLocal);
  if (progress.phase != WorkdayPhase.onBreak || !progress.isLive) return null;

  final startedAt = day.punches.last.occurredAtUtc;
  final dueAt = startedAt.add(Duration(minutes: current.breakMinutes));
  return BreakReminderPlan(
    dueAt: dueAt.toLocal(),
    followUpAt: dueAt.add(breakReminderFollowUp).toLocal(),
  );
}
