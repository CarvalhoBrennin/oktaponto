import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/features/schedule/domain/schedule_reminders.dart';
import 'package:oktaponto/features/schedule/domain/work_schedule.dart';

void main() {
  group('avisos da jornada na janela de agendamento', () {
    test('pula feriados nacionais e fins de semana', () {
      // 2 a 6 de abril de 2026: 3 é Sexta-feira Santa; 4 e 5 são sábado e
      // domingo. Sobram quinta (2) e segunda (6), com os quatro avisos cada.
      final occurrences = upcomingScheduleReminders(
        schedule: WorkSchedule.defaults,
        now: DateTime(2026, 4, 2, 7),
        days: 5,
      );

      expect(occurrences, hasLength(8));
      expect(occurrences.map((o) => o.at.day).toSet(), {2, 6});
    });

    test('horário com antecedência vira o instante do disparo', () {
      final occurrences = upcomingScheduleReminders(
        schedule: WorkSchedule.defaults,
        now: DateTime(2026, 4, 2, 7),
        days: 1,
      );

      // A entrada das 09:00 dispara 10 minutos antes, às 08:50.
      expect(occurrences.first.reminder.slot, 0);
      expect(occurrences.first.at, DateTime(2026, 4, 2, 8, 50));
    });

    test('horários que já passaram hoje ficam de fora', () {
      final occurrences = upcomingScheduleReminders(
        schedule: WorkSchedule.defaults,
        now: DateTime(2026, 4, 2, 13),
        days: 1,
      );

      // Entrada, almoço e volta já passaram; sobra a saída final, às 17:50.
      expect(occurrences.map((o) => o.reminder.slot), [3]);
    });

    test('a janela padrão cobre duas semanas e não passa disso', () {
      final occurrences = upcomingScheduleReminders(
        schedule: WorkSchedule.defaults,
        now: DateTime(2026, 4, 2, 7),
      );

      expect(
        occurrences.any((o) => o.at == DateTime(2026, 4, 15, 8, 50)),
        isTrue,
      );
      expect(
        occurrences.every((o) => o.at.isBefore(DateTime(2026, 4, 16))),
        isTrue,
      );
    });

    test('lembretes desligados não geram nenhum aviso', () {
      final occurrences = upcomingScheduleReminders(
        schedule: WorkSchedule.defaults.copyWith(remindersEnabled: false),
        now: DateTime(2026, 4, 2, 7),
      );

      expect(occurrences, isEmpty);
    });
  });
}
