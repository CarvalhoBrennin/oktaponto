import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time_utils.dart';
import '../../../providers/app_providers.dart';
import '../../schedule/presentation/schedule_provider.dart';
import '../domain/reminder_sync.dart';

/// Reschedules all recurring reminders from the current state.
///
/// Called whenever the work schedule or manual reminder list changes. By
/// default, failures are logged so the next app launch can reconcile without
/// interrupting the current flow. Screens that need to roll back a persisted
/// change can request that failures be rethrown.
Future<void> refreshRecurringReminders(
  WidgetRef ref, {
  bool rethrowOnFailure = false,
}) async {
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
    if (rethrowOnFailure) {
      throw StateError(
        'Não foi possível atualizar os lembretes. Tente novamente; '
        'se o problema continuar, confira as permissões do aparelho.',
      );
    }
  }
}

/// Updates the break reminder after punches on [date] change.
///
/// Only today can arm a reminder; correcting a past day must not schedule a
/// notification.
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
