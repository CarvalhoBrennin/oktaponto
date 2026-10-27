import 'dart:convert';

import '../../../core/time/time_utils.dart';
import '../../punch/domain/models.dart';
import '../../schedule/domain/work_schedule.dart';

String overtimeReportSourceSignature(
  MonthSummary month,
  WorkSchedule schedule,
) {
  final buffer = StringBuffer()
    ..write(month.year)
    ..write('|')
    ..write(month.month)
    ..write('|')
    ..write(jsonEncode(schedule.toJson()));

  final days = [...month.days]..sort((a, b) => a.date.compareTo(b.date));
  for (final day in days) {
    buffer
      ..write('\nD:')
      ..write(localDateKey(day.date))
      ..write('|')
      ..write(day.status.name)
      ..write('|')
      ..write(day.workedMinutes)
      ..write('|')
      ..write(day.targetMinutes ?? '')
      ..write('|')
      ..write(day.balanceMinutes ?? '')
      ..write('|')
      ..write(day.hasBlockingIssues ? '1' : '0');
    for (final punch in day.punches) {
      buffer
        ..write('\nP:')
        ..write(punch.id)
        ..write('|')
        ..write(punch.localDate)
        ..write('|')
        ..write(punch.occurredAtUtc.microsecondsSinceEpoch)
        ..write('|')
        ..write(punch.utcOffsetMinutes)
        ..write('|')
        ..write(punch.kind.name);
    }
  }
  return buffer.toString();
}
