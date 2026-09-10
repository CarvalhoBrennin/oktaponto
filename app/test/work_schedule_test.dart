import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/features/punch/domain/models.dart';
import 'package:oktaponto/features/punch/domain/work_hours_calculator.dart';
import 'package:oktaponto/features/schedule/domain/schedule_reminders.dart';
import 'package:oktaponto/features/schedule/domain/work_schedule.dart';

const _calculator = DefaultWorkHoursCalculator();

Punch _punch(int id, int hourUtc, PunchKind kind) => Punch(
  id: id,
  occurredAtUtc: DateTime.utc(2026, 9, 9, hourUtc),
  localDate: '2026-09-09',
  utcOffsetMinutes: 0,
  kind: kind,
  isEdited: false,
);

WorkDaySummary _day(List<Punch> punches) => _calculator.calculate(
  DateTime(2026, 9, 9),
  punches,
  const WorkDayMetadata(localDate: '2026-09-09'),
);

void main() {
  group('meta do dia', () {
    test('desconta o intervalo do intervalo entre entrada e saída', () {
      const schedule = WorkSchedule.defaults; // 09:00–18:00 com 1h
      expect(schedule.targetMinutes, 480);
      expect(schedule.isValid, isTrue);
    });

    test('jornada que atravessa a meia-noite é recusada', () {
      const schedule = WorkSchedule.defaults;
      final overnight = schedule.copyWith(
        startMinuteOfDay: 22 * 60,
        endMinuteOfDay: 6 * 60,
      );
      expect(overnight.problem, contains('meia-noite'));
    });

    test('intervalo maior que a jornada é recusado', () {
      final impossible = WorkSchedule.defaults.copyWith(breakMinutes: 10 * 60);
      expect(impossible.isValid, isFalse);
    });

    test('intervalo fixo precisa caber entre entrada e saída', () {
      final late = WorkSchedule.defaults.copyWith(
        breakStartMinuteOfDay: 17 * 60 + 30,
      );
      expect(late.problem, contains('depois da saída'));
      final early = WorkSchedule.defaults.copyWith(
        breakStartMinuteOfDay: 8 * 60,
      );
      expect(early.problem, contains('antes da entrada'));
    });

    test('lembrete ligado sem nenhum dia é recusado', () {
      final noDays = WorkSchedule.defaults.copyWith(weekdaysMask: 0);
      expect(noDays.isValid, isFalse);
      // Sem lembrete, os dias não importam e a jornada continua utilizável.
      expect(noDays.copyWith(remindersEnabled: false).isValid, isTrue);
    });
  });

  group('persistência', () {
    test('ida e volta por JSON preserva a jornada', () {
      final schedule = WorkSchedule.defaults.copyWith(
        startMinuteOfDay: 7 * 60 + 30,
        breakMode: BreakMode.flexible,
        breakMinutes: 45,
        leadMinutes: 5,
      );
      expect(WorkSchedule.fromJson(schedule.toJson()), schedule);
    });

    test('campos ausentes ou corrompidos caem no padrão', () {
      final recovered = WorkSchedule.fromJson(<String, Object?>{
        'startMinuteOfDay': 'oito horas',
        'breakMode': 'inexistente',
      });
      expect(
        recovered.startMinuteOfDay,
        WorkSchedule.defaults.startMinuteOfDay,
      );
      expect(recovered.breakMode, WorkSchedule.defaults.breakMode);
    });
  });

  group('avisos recorrentes', () {
    test('intervalo fixo gera os quatro avisos, com antecedência', () {
      final planned = plannedReminders(WorkSchedule.defaults);
      expect(planned.map((r) => r.slot), [0, 1, 2, 3]);
      // 09:00 menos 10 minutos de antecedência.
      expect(planned[0].hour, 8);
      expect(planned[0].minute, 50);
      expect(planned[1].minute, 50); // 12:00 - 10
      expect(planned[2].hour, 12); // 13:00 - 10
      expect(planned[3].hour, 17); // 18:00 - 10
    });

    test('intervalo livre não agenda saída nem retorno com hora marcada', () {
      final planned = plannedReminders(
        WorkSchedule.defaults.copyWith(breakMode: BreakMode.flexible),
      );
      expect(planned.map((r) => r.slot), [0, 3]);
    });

    test('lembretes desligados não geram nada', () {
      final planned = plannedReminders(
        WorkSchedule.defaults.copyWith(remindersEnabled: false),
      );
      expect(planned, isEmpty);
    });

    test('antecedência não empurra o aviso para o dia anterior', () {
      final planned = plannedReminders(
        WorkSchedule.defaults.copyWith(
          startMinuteOfDay: 5,
          leadMinutes: 30,
          breakStartMinuteOfDay: 12 * 60,
        ),
      );
      expect(planned.first.minuteOfDay, 0);
    });
  });

  group('aviso de fim de intervalo', () {
    final flexible = WorkSchedule.defaults.copyWith(
      breakMode: BreakMode.flexible,
      breakMinutes: 60,
      weekdaysMask: 127,
    );

    test('arma a partir da batida real, com uma insistência', () {
      final day = _day([
        _punch(1, 8, PunchKind.in_),
        _punch(2, 12, PunchKind.out),
      ]);
      final plan = planBreakReminder(
        day: day,
        schedule: flexible,
        nowLocal: DateTime.utc(2026, 9, 9, 12, 5),
      );
      expect(plan, isNotNull);
      expect(plan!.dueAt.toUtc(), DateTime.utc(2026, 9, 9, 13));
      expect(plan.followUpAt.toUtc(), DateTime.utc(2026, 9, 9, 13, 15));
    });

    test('não arma nada com intervalo de hora marcada', () {
      final day = _day([
        _punch(1, 8, PunchKind.in_),
        _punch(2, 12, PunchKind.out),
      ]);
      expect(
        planBreakReminder(
          day: day,
          schedule: WorkSchedule.defaults,
          nowLocal: DateTime.utc(2026, 9, 9, 12, 5),
        ),
        isNull,
      );
    });

    test('não arma quando o retorno já foi batido', () {
      final day = _day([
        _punch(1, 8, PunchKind.in_),
        _punch(2, 12, PunchKind.out),
        _punch(3, 13, PunchKind.in_),
      ]);
      expect(
        planBreakReminder(
          day: day,
          schedule: flexible,
          nowLocal: DateTime.utc(2026, 9, 9, 13, 5),
        ),
        isNull,
      );
    });

    test('não arma sem jornada configurada', () {
      final day = _day([
        _punch(1, 8, PunchKind.in_),
        _punch(2, 12, PunchKind.out),
      ]);
      expect(
        planBreakReminder(
          day: day,
          schedule: null,
          nowLocal: DateTime.utc(2026, 9, 9, 12, 5),
        ),
        isNull,
      );
    });

    test('não arma num dia que não é de trabalho', () {
      // 09/09/2026 é uma quarta-feira; só sábado e domingo ligados.
      final day = _day([
        _punch(1, 8, PunchKind.in_),
        _punch(2, 12, PunchKind.out),
      ]);
      expect(
        planBreakReminder(
          day: day,
          schedule: flexible.copyWith(weekdaysMask: 96),
          nowLocal: DateTime.utc(2026, 9, 9, 12, 5),
        ),
        isNull,
      );
    });

    test('não arma para um intervalo aberto em dia passado', () {
      final day = _day([
        _punch(1, 8, PunchKind.in_),
        _punch(2, 12, PunchKind.out),
      ]);
      expect(
        planBreakReminder(
          day: day,
          schedule: flexible,
          nowLocal: DateTime.utc(2026, 9, 11, 10),
        ),
        isNull,
      );
    });
  });
}
