import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time_utils.dart';
import '../../../providers/app_providers.dart';
import '../../schedule/presentation/schedule_provider.dart';
import '../domain/reminder_sync.dart';

/// Reagenda todos os avisos recorrentes a partir do estado atual.
///
/// Chamado sempre que a jornada ou a lista manual muda. Falha aqui nunca
/// interrompe o fluxo do usuário: o ponto já foi gravado, e o próximo início
/// do app reconcilia.
Future<void> refreshRecurringReminders(WidgetRef ref) async {
  try {
    final manual = await ref.read(reminderRepositoryProvider).listAll();
    final setup = await ref.read(scheduleSetupProvider.future);
    await syncRecurringReminders(
      notifications: ref.read(notificationServiceProvider),
      manualReminders: manual,
      schedule: setup.schedule,
    );
  } catch (error, stackTrace) {
    logReminderFailure(error, stackTrace);
  }
}

/// Acerta o aviso de fim de intervalo depois de mexer nas batidas de [date].
///
/// Só o dia de hoje arma aviso; corrigir uma quarta-feira passada não deve
/// programar notificação nenhuma.
Future<void> refreshBreakReminder(WidgetRef ref, DateTime date) async {
  try {
    final now = ref.read(clockProvider).now();
    if (dateOnly(date) != dateOnly(now)) return;
    final day = await ref.read(daySummaryProvider(dateOnly(now)).future);
    await syncBreakReminder(
      notifications: ref.read(notificationServiceProvider),
      today: day,
      schedule: ref.read(workScheduleProvider),
      nowLocal: now,
    );
  } catch (error, stackTrace) {
    logReminderFailure(error, stackTrace);
  }
}
