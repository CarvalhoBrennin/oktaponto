import '../../../core/time/time_utils.dart';
import '../../../core/validation/punch_sequence_validator.dart';
import 'models.dart';

abstract interface class WorkHoursCalculator {
  WorkDaySummary calculate(
    DateTime date,
    List<Punch> punches,
    WorkDayMetadata metadata,
  );
}

final class DefaultWorkHoursCalculator implements WorkHoursCalculator {
  const DefaultWorkHoursCalculator({
    this.sequenceValidator = const PunchSequenceValidator(),
  });

  final PunchSequenceValidator sequenceValidator;

  @override
  WorkDaySummary calculate(
    DateTime date,
    List<Punch> punches,
    WorkDayMetadata metadata,
  ) {
    // Validate the repository/input order before sorting. Sorting first would
    // hide corrupt or out-of-order source data, which must fail closed.
    final issues = [...sequenceValidator.validate(punches)];
    final sorted = [...punches]
      ..sort((a, b) => a.occurredAtUtc.compareTo(b.occurredAtUtc));

    var workedMinutes = 0;
    for (var index = 0; index + 1 < sorted.length; index += 2) {
      if (sorted[index].kind != PunchKind.in_ || sorted[index + 1].kind != PunchKind.out) {
        continue;
      }
      final duration = sorted[index + 1].occurredAtUtc.difference(sorted[index].occurredAtUtc);
      if (!duration.isNegative && duration > Duration.zero) {
        workedMinutes += duration.inMinutes;
      }
    }

    final key = localDateKey(date);
    if (sorted.any(
      (punch) =>
          punch.localDate != key ||
          localDateKey(punch.occurredAtLocal) != key,
    )) {
      issues.add(
        const ValidationIssue(
          'cross_local_date',
          'Há batidas associadas a outra data local. Jornada overnight exige revisão manual.',
        ),
      );
    }
    if (workedMinutes > 1440) {
      issues.add(
        const ValidationIssue(
          'worked_over_24h',
          'O total diário não pode ultrapassar 24:00.',
        ),
      );
    }

    final status = issues.any((issue) => issue.blocking)
        ? WorkDayStatus.invalid
        : switch (sorted.length) {
            0 => WorkDayStatus.empty,
            1 => WorkDayStatus.open,
            2 => WorkDayStatus.paused,
            3 => WorkDayStatus.open,
            4 => WorkDayStatus.complete,
            _ => WorkDayStatus.invalid,
          };

    return WorkDaySummary(
      date: dateOnly(date),
      punches: List.unmodifiable(sorted),
      status: status,
      workedMinutes: workedMinutes,
      includeInTimesheet: metadata.includeInTimesheet,
      activity: metadata.activity,
      note: metadata.note,
      issues: List.unmodifiable(issues),
    );
  }
}
