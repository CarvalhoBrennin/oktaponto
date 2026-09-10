import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/work_schedule_store.dart';
import '../domain/work_schedule.dart';

final workScheduleStoreProvider = Provider<WorkScheduleStore>(
  (ref) => const PrefsWorkScheduleStore(),
);

/// Estado da configuração inicial, hidratado do armazenamento do aparelho.
///
/// É assíncrono de propósito: enquanto carrega, o app não sabe se deve abrir a
/// apresentação ou a tela Hoje, e mostrar a escolha errada por um frame seria
/// pior do que segurar um instante.
class ScheduleSetupNotifier extends AsyncNotifier<ScheduleSetup> {
  WorkScheduleStore get _store => ref.read(workScheduleStoreProvider);

  @override
  Future<ScheduleSetup> build() => _store.load();

  /// Grava a jornada e marca a apresentação como concluída.
  Future<void> save(WorkSchedule schedule) async {
    await _store.save(schedule);
    await _store.markOnboardingSeen();
    state = AsyncData(ScheduleSetup(onboardingSeen: true, schedule: schedule));
  }

  /// Encerra a apresentação sem definir jornada.
  ///
  /// Sem jornada não há meta do dia nem lembrete automático — e é isso que o
  /// usuário pediu ao pular. Ele configura depois em Configurações.
  Future<void> skipOnboarding() async {
    await _store.markOnboardingSeen();
    final current = state.value;
    state = AsyncData(
      ScheduleSetup(onboardingSeen: true, schedule: current?.schedule),
    );
  }

  /// Volta o aparelho ao estado de primeira abertura.
  Future<void> reset() async {
    await _store.clear();
    state = const AsyncData(ScheduleSetup.initial);
  }

  /// Reabre a apresentação mantendo a jornada atual como ponto de partida.
  void replayOnboarding() {
    final current = state.value;
    state = AsyncData(
      ScheduleSetup(onboardingSeen: false, schedule: current?.schedule),
    );
  }
}

final scheduleSetupProvider =
    AsyncNotifierProvider<ScheduleSetupNotifier, ScheduleSetup>(
      ScheduleSetupNotifier.new,
    );

/// Jornada em vigor, ou `null` enquanto ela não foi definida.
final workScheduleProvider = Provider<WorkSchedule?>(
  (ref) => ref.watch(scheduleSetupProvider).value?.schedule,
);

/// Meta diária em minutos, ou `null` sem jornada definida.
final dailyTargetMinutesProvider = Provider<int?>(
  (ref) => ref.watch(scheduleSetupProvider).value?.targetMinutes,
);

/// Log padronizado para falhas de agendamento, que nunca devem derrubar o app
/// de ponto — o próximo início ou a próxima edição reconciliam.
void logReminderFailure(Object error, StackTrace stackTrace) {
  debugPrint('OktaPonto: falha ao agendar lembretes: $error');
  debugPrintStack(stackTrace: stackTrace);
}
