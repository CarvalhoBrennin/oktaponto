import '../../punch/domain/models.dart';
import '../../punch/domain/work_hours_calculator.dart';

abstract interface class MonthlyCloseValidator {
  MonthValidationResult validate(MonthSummary month);
}

final class DefaultMonthlyCloseValidator implements MonthlyCloseValidator {
  const DefaultMonthlyCloseValidator({
    this.calculator = const DefaultWorkHoursCalculator(),
  });

  final WorkHoursCalculator calculator;

  @override
  MonthValidationResult validate(MonthSummary month) {
    final issues = <ValidationIssue>[];
    final seen = <String>{};

    for (final day in month.days) {
      final key =
          '${day.date.year.toString().padLeft(4, '0')}-'
          '${day.date.month.toString().padLeft(2, '0')}-'
          '${day.date.day.toString().padLeft(2, '0')}';
      if (day.date.year != month.year || day.date.month != month.month) {
        issues.add(
          ValidationIssue(
            'wrong_month_$key',
            'O dia $key não pertence ao mês ${month.month.toString().padLeft(2, '0')}/${month.year}.',
          ),
        );
        continue;
      }
      if (!seen.add(key)) {
        issues.add(
          ValidationIssue(
            'duplicate_date_$key',
            'Há data duplicada no fechamento: $key.',
          ),
        );
        continue;
      }
      if (!day.includeInTimesheet) continue;

      // Re-derive the day from punches at the export boundary. This prevents a
      // manually-constructed or stale WorkDaySummary from being trusted as an
      // authoritative source of worked minutes/status.
      final recalculated = calculator.calculate(
        day.date,
        day.punches,
        WorkDayMetadata(
          localDate: key,
          includeInTimesheet: day.includeInTimesheet,
          activity: day.activity,
          note: day.note,
        ),
      );
      if (recalculated.status != day.status ||
          recalculated.workedMinutes != day.workedMinutes) {
        issues.add(
          ValidationIssue(
            'derived_mismatch_$key',
            'O resumo derivado do dia $key não corresponde às batidas armazenadas.',
          ),
        );
      }
      if (recalculated.issues.any((issue) => issue.blocking)) {
        issues.addAll(recalculated.issues.where((issue) => issue.blocking));
      }
      if (day.status != WorkDayStatus.complete) {
        issues.add(
          ValidationIssue(
            'incomplete_$key',
            'O dia $key está incluído, mas não possui quatro batidas válidas.',
          ),
        );
      }
      if (day.workedMinutes <= 0) {
        issues.add(
          ValidationIssue(
            'non_positive_$key',
            'O dia $key não possui horas positivas.',
          ),
        );
      }
      if (day.workedMinutes > 1440) {
        issues.add(
          ValidationIssue('over_24h_$key', 'O dia $key ultrapassa 24:00.'),
        );
      }
      issues.addAll(day.issues.where((issue) => issue.blocking));
    }

    final included = month.days.where((day) => day.includeInTimesheet).toList();
    if (included.isEmpty) {
      issues.add(
        const ValidationIssue(
          'empty_month',
          'Nenhum dia foi selecionado para o timesheet.',
        ),
      );
    }

    return MonthValidationResult(List.unmodifiable(issues));
  }
}
