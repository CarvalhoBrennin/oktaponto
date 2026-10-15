enum PunchKind { in_, out }

enum WorkDayStatus { empty, open, paused, complete, invalid }

final class Punch {
  const Punch({
    required this.id,
    required this.occurredAtUtc,
    required this.localDate,
    required this.utcOffsetMinutes,
    required this.kind,
    required this.isEdited,
  });

  final int id;
  final DateTime occurredAtUtc;
  final String localDate;
  final int utcOffsetMinutes;
  final PunchKind kind;
  final bool isEdited;

  DateTime get occurredAtLocal =>
      occurredAtUtc.toUtc().add(Duration(minutes: utcOffsetMinutes));

  Punch copyWith({
    int? id,
    DateTime? occurredAtUtc,
    String? localDate,
    int? utcOffsetMinutes,
    PunchKind? kind,
    bool? isEdited,
  }) {
    return Punch(
      id: id ?? this.id,
      occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
      localDate: localDate ?? this.localDate,
      utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
      kind: kind ?? this.kind,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}

final class PunchDraft {
  const PunchDraft({
    required this.localDate,
    required this.occurredAtUtc,
    required this.utcOffsetMinutes,
    required this.kind,
    this.isEdited = false,
  });

  final String localDate;
  final DateTime occurredAtUtc;
  final int utcOffsetMinutes;
  final PunchKind kind;
  final bool isEdited;
}

/// Horários locais de um dia que será preenchido em lote.
///
/// A operação aceita apenas dias ainda sem batidas e grava os quatro horários
/// como correções manuais, com a mesma validação e auditoria das edições.
final class ManualPunchBatchDay {
  const ManualPunchBatchDay({required this.date, required this.localTimes});

  final DateTime date;
  final List<DateTime> localTimes;
}

final class PunchEdit {
  const PunchEdit({
    required this.id,
    required this.localDate,
    required this.occurredAtUtc,
    required this.utcOffsetMinutes,
    required this.kind,
  });

  final int id;
  final String localDate;
  final DateTime occurredAtUtc;
  final int utcOffsetMinutes;
  final PunchKind kind;
}

final class WorkDayMetadata {
  const WorkDayMetadata({
    required this.localDate,
    this.includeInTimesheet = true,
    this.activity,
    this.note,
  });

  final String localDate;
  final bool includeInTimesheet;
  final String? activity;
  final String? note;

  WorkDayMetadata copyWith({
    bool? includeInTimesheet,
    String? activity,
    bool clearActivity = false,
    String? note,
    bool clearNote = false,
  }) {
    return WorkDayMetadata(
      localDate: localDate,
      includeInTimesheet: includeInTimesheet ?? this.includeInTimesheet,
      activity: clearActivity ? null : (activity ?? this.activity),
      note: clearNote ? null : (note ?? this.note),
    );
  }
}

final class ValidationIssue {
  const ValidationIssue(this.code, this.message, {this.blocking = true});

  final String code;
  final String message;
  final bool blocking;
}

final class WorkDaySummary {
  const WorkDaySummary({
    required this.date,
    required this.punches,
    required this.status,
    required this.workedMinutes,
    required this.includeInTimesheet,
    required this.activity,
    required this.issues,
    this.note,
    this.targetMinutes,
    this.balanceMinutes,
  });

  final DateTime date;
  final List<Punch> punches;
  final WorkDayStatus status;
  final int workedMinutes;
  final bool includeInTimesheet;
  final String? activity;
  final String? note;
  final List<ValidationIssue> issues;

  /// Target derived from the configured schedule, or null without one.
  final int? targetMinutes;

  /// Day balance against the target, derived from punches. May be negative.
  final int? balanceMinutes;

  bool get hasBlockingIssues => issues.any((issue) => issue.blocking);

  /// Positive minutes that can be accumulated in the bank for this day.
  int get overtimeMinutes {
    final balance = balanceMinutes;
    return balance == null || balance <= 0 ? 0 : balance;
  }

  // Timesheet inclusion controls export only; bank hours use valid punches.
  bool get isEligibleForBankHours =>
      status == WorkDayStatus.complete &&
      !hasBlockingIssues &&
      targetMinutes != null &&
      balanceMinutes != null;

  bool get isEligibleForTimesheet =>
      status == WorkDayStatus.complete &&
      includeInTimesheet &&
      workedMinutes > 0 &&
      workedMinutes <= 1440 &&
      !hasBlockingIssues;
}

final class ProfileSettingsModel {
  const ProfileSettingsModel({
    this.employeeName = '',
    this.jobTitle = '',
    this.workMode = '',
    this.defaultActivity = '',
  });

  final String employeeName;
  final String jobTitle;
  final String workMode;
  final String defaultActivity;

  ProfileSettingsModel copyWith({
    String? employeeName,
    String? jobTitle,
    String? workMode,
    String? defaultActivity,
  }) {
    return ProfileSettingsModel(
      employeeName: employeeName ?? this.employeeName,
      jobTitle: jobTitle ?? this.jobTitle,
      workMode: workMode ?? this.workMode,
      defaultActivity: defaultActivity ?? this.defaultActivity,
    );
  }
}

final class MonthSummary {
  const MonthSummary({
    required this.year,
    required this.month,
    required this.days,
  });

  final int year;
  final int month;
  final List<WorkDaySummary> days;

  int get totalMinutes => days
      .where((day) => day.isEligibleForTimesheet)
      .fold(0, (sum, day) => sum + day.workedMinutes);

  /// Minutes above target on complete, consistent days.
  int get overtimeMinutes => days.fold(
    0,
    (sum, day) => sum + (day.isEligibleForBankHours ? day.overtimeMinutes : 0),
  );

  /// Net bank balance: overtime minutes minus minutes below target.
  int get bankBalanceMinutes => days.fold(
    0,
    (sum, day) =>
        sum + (day.isEligibleForBankHours ? (day.balanceMinutes ?? 0) : 0),
  );

  int get bankHoursDayCount =>
      days.where((day) => day.isEligibleForBankHours).length;

  /// Complete bank-hour days with positive balance, ordered chronologically.
  List<WorkDaySummary> get daysWithOvertime =>
      _sortedBankDays((day) => day.overtimeMinutes > 0);

  /// Complete bank-hour days with negative balance, ordered chronologically.
  List<WorkDaySummary> get daysWithDeficit =>
      _sortedBankDays((day) => (day.balanceMinutes ?? 0) < 0);

  List<WorkDaySummary> _sortedBankDays(
    bool Function(WorkDaySummary day) predicate,
  ) {
    final result = days
        .where((day) => day.isEligibleForBankHours && predicate(day))
        .toList();
    result.sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(result);
  }
}

final class MonthValidationResult {
  const MonthValidationResult(this.issues);

  final List<ValidationIssue> issues;

  bool get isValid => !issues.any((issue) => issue.blocking);
}

final class TimesheetGenerationResult {
  const TimesheetGenerationResult({
    required this.outputPath,
    required this.includedDays,
    required this.totalMinutes,
    required this.periodStart,
    required this.periodEnd,
    required this.monthYear,
  });

  final String outputPath;
  final int includedDays;
  final int totalMinutes;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String monthYear;
}
