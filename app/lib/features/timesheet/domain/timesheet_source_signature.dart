import '../../punch/domain/models.dart';

/// Canonical, deterministic representation of every user-controlled value that
/// affects a monthly export. It is intentionally not cryptographic: it is a
/// change detector used to prevent sharing a workbook generated from stale app
/// state.
String timesheetSourceSignature(
  MonthSummary month,
  ProfileSettingsModel profile,
) {
  final buffer = StringBuffer()
    ..write(month.year)
    ..write('|')
    ..write(month.month)
    ..write('|')
    ..write(_escape(profile.employeeName))
    ..write('|')
    ..write(_escape(profile.jobTitle))
    ..write('|')
    ..write(_escape(profile.workMode))
    ..write('|')
    ..write(_escape(profile.defaultActivity));

  final days = [...month.days]..sort((a, b) => a.date.compareTo(b.date));
  for (final day in days) {
    buffer
      ..write('\nD:')
      ..write(day.date.toIso8601String())
      ..write('|')
      ..write(day.includeInTimesheet ? '1' : '0')
      ..write('|')
      ..write(_escape(day.activity ?? ''))
      ..write('|')
      ..write(_escape(day.note ?? ''))
      ..write('|')
      ..write(day.status.name)
      ..write('|')
      ..write(day.workedMinutes);
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
        ..write(punch.kind.name)
        ..write('|')
        ..write(punch.isEdited ? '1' : '0');
    }
  }
  return buffer.toString();
}

String _escape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('|', '\\|')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\r');
