import '../../../core/time/time_utils.dart';
import '../../punch/domain/models.dart';
import '../../schedule/domain/work_schedule.dart';

/// Configuração dos quatro horários aplicados aos dias faltantes.
///
/// O total trabalhado é sempre derivado destes horários. Por padrão, a meta é
/// 08:00 e os horários de entrada/intervalo vêm da escala configurada.
final class WorkdayFillPattern {
  const WorkdayFillPattern({
    required this.startMinuteOfDay,
    required this.breakStartMinuteOfDay,
    required this.breakMinutes,
    this.workedMinutes = 8 * 60,
  });

  factory WorkdayFillPattern.fromSchedule(WorkSchedule? schedule) {
    final configured = schedule?.isValid == true
        ? schedule!
        : WorkSchedule.defaults;
    final start =
        configured.startMinuteOfDay >= 0 &&
            configured.startMinuteOfDay < 24 * 60
        ? configured.startMinuteOfDay
        : WorkSchedule.defaults.startMinuteOfDay;
    final breakMinutes =
        configured.breakMinutes >= 15 && configured.breakMinutes <= 3 * 60
        ? configured.breakMinutes
        : WorkSchedule.defaults.breakMinutes;
    var breakStart = configured.breakMode == BreakMode.fixed
        ? configured.breakStartMinuteOfDay
        : 12 * 60;
    final endMinute = start + 8 * 60 + breakMinutes;
    if (breakStart <= start || breakStart + breakMinutes >= endMinute) {
      breakStart = start + 4 * 60;
    }
    final pattern = WorkdayFillPattern(
      startMinuteOfDay: start,
      breakStartMinuteOfDay: breakStart,
      breakMinutes: breakMinutes,
    );
    if (pattern.isValid) return pattern;
    return const WorkdayFillPattern(
      startMinuteOfDay: 9 * 60,
      breakStartMinuteOfDay: 12 * 60,
      breakMinutes: 60,
    );
  }

  final int startMinuteOfDay;
  final int breakStartMinuteOfDay;
  final int breakMinutes;
  final int workedMinutes;

  int get breakEndMinuteOfDay => breakStartMinuteOfDay + breakMinutes;
  int get endMinuteOfDay => startMinuteOfDay + workedMinutes + breakMinutes;

  String? get problem {
    if (startMinuteOfDay < 0 || startMinuteOfDay >= 24 * 60) {
      return 'Escolha um horário de entrada válido.';
    }
    if (workedMinutes < 30 || workedMinutes > 16 * 60) {
      return 'As horas trabalhadas precisam ficar entre 00h30 e 16h00.';
    }
    if (breakMinutes < 15 || breakMinutes > 3 * 60) {
      return 'O almoço precisa durar entre 15 minutos e 3 horas.';
    }
    if (breakStartMinuteOfDay <= startMinuteOfDay ||
        breakStartMinuteOfDay >= 24 * 60) {
      return 'O início do almoço precisa ser depois da entrada.';
    }
    if (breakEndMinuteOfDay >= endMinuteOfDay || endMinuteOfDay >= 24 * 60) {
      return 'Os horários precisam terminar no mesmo dia e deixar tempo '
          'de trabalho antes e depois do almoço.';
    }
    return null;
  }

  bool get isValid => problem == null;

  WorkdayFillPattern copyWith({
    int? startMinuteOfDay,
    int? breakStartMinuteOfDay,
    int? breakMinutes,
    int? workedMinutes,
  }) => WorkdayFillPattern(
    startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
    breakStartMinuteOfDay: breakStartMinuteOfDay ?? this.breakStartMinuteOfDay,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    workedMinutes: workedMinutes ?? this.workedMinutes,
  );

  List<DateTime> timesFor(DateTime date) {
    final issue = problem;
    if (issue != null) throw StateError(issue);
    return List<DateTime>.unmodifiable([
      _atMinute(date, startMinuteOfDay),
      _atMinute(date, breakStartMinuteOfDay),
      _atMinute(date, breakEndMinuteOfDay),
      _atMinute(date, endMinuteOfDay),
    ]);
  }

  DateTime _atMinute(DateTime date, int minuteOfDay) => DateTime(
    date.year,
    date.month,
    date.day,
    minuteOfDay ~/ 60,
    minuteOfDay % 60,
  );
}

/// Retorna dias de trabalho anteriores a hoje, sem batidas e ainda incluídos
/// no timesheet. Dias futuros, hoje, fins de semana fora da escala e datas
/// excluídas manualmente não recebem registros.
List<DateTime> missingScheduledWorkdays({
  required MonthSummary month,
  required WorkSchedule? schedule,
  required DateTime now,
}) {
  final effectiveSchedule = schedule?.isValid == true
      ? schedule!
      : WorkSchedule.defaults;
  final today = DateTime(now.year, now.month, now.day);
  final hasPunches = <String>{};
  final excludedDates = <String>{};
  for (final day in month.days) {
    if (day.date.year != month.year || day.date.month != month.month) continue;
    final key = localDateKey(day.date);
    if (day.punches.isNotEmpty) hasPunches.add(key);
    if (!day.includeInTimesheet) excludedDates.add(key);
  }

  final missing = <DateTime>[];
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  for (var dayNumber = 1; dayNumber <= daysInMonth; dayNumber++) {
    final date = DateTime(month.year, month.month, dayNumber);
    if (!date.isBefore(today)) break;
    if (!effectiveSchedule.includesWeekday(date.weekday)) continue;
    final key = localDateKey(date);
    if (hasPunches.contains(key) || excludedDates.contains(key)) continue;
    missing.add(date);
  }
  return List<DateTime>.unmodifiable(missing);
}

/// Texto de relógio para os horários do padrão de preenchimento.
String formatFillMinute(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

/// Texto de duração sem ambiguidade entre duração e horário do dia.
String formatFillDuration(int minutes) => minutesToCompactHm(minutes);
