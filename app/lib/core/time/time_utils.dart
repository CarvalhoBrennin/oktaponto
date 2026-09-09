import 'package:intl/intl.dart';

const weekdaysPt = <int, String>{
  DateTime.monday: 'Segunda-feira',
  DateTime.tuesday: 'Terça-feira',
  DateTime.wednesday: 'Quarta-feira',
  DateTime.thursday: 'Quinta-feira',
  DateTime.friday: 'Sexta-feira',
  DateTime.saturday: 'Sábado',
  DateTime.sunday: 'Domingo',
};

const monthsPtUpper = <int, String>{
  1: 'JANEIRO',
  2: 'FEVEREIRO',
  3: 'MARÇO',
  4: 'ABRIL',
  5: 'MAIO',
  6: 'JUNHO',
  7: 'JULHO',
  8: 'AGOSTO',
  9: 'SETEMBRO',
  10: 'OUTUBRO',
  11: 'NOVEMBRO',
  12: 'DEZEMBRO',
};

const monthsPtSlug = <int, String>{
  1: 'janeiro',
  2: 'fevereiro',
  3: 'marco',
  4: 'abril',
  5: 'maio',
  6: 'junho',
  7: 'julho',
  8: 'agosto',
  9: 'setembro',
  10: 'outubro',
  11: 'novembro',
  12: 'dezembro',
};


/// Converts a wall-clock date/time plus its captured UTC offset into UTC.
/// This is used when editing historical punches so a later device timezone
/// change does not silently reinterpret the original local time.
DateTime wallClockToUtc(DateTime wallClock, int utcOffsetMinutes) => DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
      wallClock.millisecond,
      wallClock.microsecond,
    ).subtract(Duration(minutes: utcOffsetMinutes));

String localDateKey(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime parseLocalDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    throw FormatException('Data local inválida: $value');
  }
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

String weekdayPt(DateTime date) => weekdaysPt[date.weekday]!;

String monthYearPt(DateTime date) => '${monthsPtUpper[date.month]} ${date.year}';

String defaultFilenameForMonth(DateTime date) =>
    'timesheet_${monthsPtSlug[date.month]}_${date.year}.xlsx';

(DateTime, DateTime) monthBounds(DateTime date) {
  final start = DateTime(date.year, date.month);
  final end = DateTime(date.year, date.month + 1, 0);
  return (start, end);
}

String minutesToHhmm(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return '$hours:${rest.toString().padLeft(2, '0')}';
}

String formatClock(DateTime local) => DateFormat('HH:mm').format(local);

String formatDateBr(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
