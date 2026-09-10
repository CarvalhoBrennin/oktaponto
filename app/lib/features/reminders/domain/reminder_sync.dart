import '../../punch/domain/models.dart';
import '../../schedule/domain/schedule_reminders.dart';
import '../../schedule/domain/work_schedule.dart';
import '../data/local_notification_service.dart';
import 'reminder.dart';

/// Reagenda tudo que é recorrente: a lista manual e os avisos da jornada.
///
/// Existe um único ponto de entrada porque os dois conjuntos compartilham o
/// agendador do sistema; recalcular só metade apagaria a outra.
Future<void> syncRecurringReminders({
  required LocalNotificationService notifications,
  required List<ReminderConfig> manualReminders,
  required WorkSchedule? schedule,
}) async {
  final planned = schedule == null
      ? const <ScheduleReminder>[]
      : plannedReminders(schedule);
  await notifications.rescheduleAll(
    manualReminders,
    scheduleReminders: planned,
    scheduleWeekdaysMask: schedule?.weekdaysMask ?? 0,
  );
}

/// Acerta o aviso de fim de intervalo com o estado real do dia.
///
/// Chamado depois de qualquer mudança nas batidas de hoje: sair para o
/// intervalo arma o aviso, voltar cancela. Com intervalo fixo nunca há o que
/// agendar aqui — aquele caso já é um aviso recorrente.
Future<void> syncBreakReminder({
  required LocalNotificationService notifications,
  required WorkDaySummary today,
  required WorkSchedule? schedule,
  required DateTime nowLocal,
}) async {
  final plan = planBreakReminder(
    day: today,
    schedule: schedule,
    nowLocal: nowLocal,
  );
  if (plan == null) {
    await notifications.cancelBreakReminder();
    return;
  }
  await notifications.scheduleBreakReminder(plan);
}
