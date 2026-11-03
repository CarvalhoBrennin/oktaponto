/// Feriado nacional brasileiro em uma data.
final class NationalHoliday {
  const NationalHoliday({required this.date, required this.name});

  /// Dia do feriado, à meia-noite local.
  final DateTime date;

  /// Nome curto, como aparece no calendário e no histórico.
  final String name;
}

/// Feriados nacionais do Brasil de um ano, em ordem cronológica.
///
/// Calculados no próprio app, sem lista externa nem rede. Cobrem os feriados
/// fixos (Lei 662/1949) e a Sexta-feira Santa, que acompanha a Páscoa. O Dia
/// da Consciência Negra entra a partir de 2024, pela Lei 14.759/2023.
///
/// Não cobrem feriados estaduais ou municipais nem pontos facultativos, como
/// Carnaval e Corpus Christi: variam de lugar para lugar.
List<NationalHoliday> nationalHolidaysOf(int year) {
  final easter = _easterSunday(year);
  final holidays = <NationalHoliday>[
    NationalHoliday(
      date: DateTime(year, 1, 1),
      name: 'Confraternização Universal',
    ),
    NationalHoliday(
      date: DateTime(easter.year, easter.month, easter.day - 2),
      name: 'Sexta-feira Santa',
    ),
    NationalHoliday(date: DateTime(year, 4, 21), name: 'Tiradentes'),
    NationalHoliday(date: DateTime(year, 5, 1), name: 'Dia do Trabalho'),
    NationalHoliday(
      date: DateTime(year, 9, 7),
      name: 'Independência do Brasil',
    ),
    NationalHoliday(
      date: DateTime(year, 10, 12),
      name: 'Nossa Senhora Aparecida',
    ),
    NationalHoliday(date: DateTime(year, 11, 2), name: 'Finados'),
    NationalHoliday(
      date: DateTime(year, 11, 15),
      name: 'Proclamação da República',
    ),
    if (year >= 2024)
      NationalHoliday(date: DateTime(year, 11, 20), name: 'Consciência Negra'),
    NationalHoliday(date: DateTime(year, 12, 25), name: 'Natal'),
  ];
  holidays.sort((a, b) => a.date.compareTo(b.date));
  return List.unmodifiable(holidays);
}

/// O feriado nacional que cai em [date], ou `null` se o dia não é feriado.
///
/// Compara só dia e mês, então a hora do dia não altera o resultado.
NationalHoliday? nationalHolidayOn(DateTime date) {
  for (final holiday in nationalHolidaysOf(date.year)) {
    if (holiday.date.month == date.month && holiday.date.day == date.day) {
      return holiday;
    }
  }
  return null;
}

/// Domingo de Páscoa pelo algoritmo anônimo gregoriano (Meeus/Jones/Butcher).
///
/// Todas as divisões são sobre valores não negativos, então `~/` e `%` dão o
/// mesmo resultado que a fórmula original.
DateTime _easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime(year, month, day);
}
