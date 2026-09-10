import '../../punch/domain/models.dart';

/// Total de uma semana do mês.
final class WeekBucket {
  const WeekBucket({required this.index, required this.minutes});

  /// Semana dentro do mês, começando em zero.
  final int index;
  final int minutes;
}

/// Agrupa em semanas (segunda a domingo) os dias elegíveis do mês.
///
/// Fica no domínio, e não no widget, porque é derivação sobre os totais já
/// calculados — a interface só desenha o que sai daqui. Nenhum minuto é
/// recalculado: cada dia contribui com o `workedMinutes` que o
/// `WorkHoursCalculator` produziu, e só entram os dias que o próprio domínio
/// considera elegíveis para o timesheet.
List<WeekBucket> weeklyDistribution(MonthSummary month) {
  final first = DateTime(month.year, month.month);
  final offset = first.weekday - DateTime.monday;
  final totals = <int, int>{};
  for (final day in month.days) {
    if (!day.isEligibleForTimesheet) continue;
    final week = (offset + day.date.day - 1) ~/ 7;
    totals[week] = (totals[week] ?? 0) + day.workedMinutes;
  }
  if (totals.isEmpty) return const [];
  final last = totals.keys.reduce((a, b) => a > b ? a : b);
  return [
    for (var i = 0; i <= last; i++)
      WeekBucket(index: i, minutes: totals[i] ?? 0),
  ];
}
