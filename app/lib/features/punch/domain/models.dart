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
  });

  final DateTime date;
  final List<Punch> punches;
  final WorkDayStatus status;
  final int workedMinutes;
  final bool includeInTimesheet;
  final String? activity;
  final String? note;
  final List<ValidationIssue> issues;

  bool get hasBlockingIssues => issues.any((issue) => issue.blocking);

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
