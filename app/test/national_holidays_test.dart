import 'package:flutter_test/flutter_test.dart';
import 'package:oktaponto/core/time/national_holidays.dart';

void main() {
  test('2026 tem os dez feriados nacionais em ordem cronológica', () {
    final holidays = nationalHolidaysOf(2026);

    expect(holidays.map((holiday) => holiday.date).toList(), [
      DateTime(2026, 1, 1),
      DateTime(2026, 4, 3),
      DateTime(2026, 4, 21),
      DateTime(2026, 5, 1),
      DateTime(2026, 9, 7),
      DateTime(2026, 10, 12),
      DateTime(2026, 11, 2),
      DateTime(2026, 11, 15),
      DateTime(2026, 11, 20),
      DateTime(2026, 12, 25),
    ]);
  });

  test('Sexta-feira Santa acompanha a Páscoa em cada ano', () {
    DateTime goodFridayOf(int year) => nationalHolidaysOf(
      year,
    ).singleWhere((holiday) => holiday.name == 'Sexta-feira Santa').date;

    expect(goodFridayOf(2024), DateTime(2024, 3, 29));
    expect(goodFridayOf(2025), DateTime(2025, 4, 18));
    expect(goodFridayOf(2027), DateTime(2027, 3, 26));
    expect(goodFridayOf(2038), DateTime(2038, 4, 23));
  });

  test('Consciência Negra só é feriado nacional a partir de 2024', () {
    expect(
      nationalHolidaysOf(2023).map((holiday) => holiday.name),
      isNot(contains('Consciência Negra')),
    );
    expect(
      nationalHolidayOn(DateTime(2024, 11, 20))?.name,
      'Consciência Negra',
    );
  });

  test('nationalHolidayOn ignora a hora do dia', () {
    expect(nationalHolidayOn(DateTime(2026, 4, 21, 0, 0))?.name, 'Tiradentes');
    expect(
      nationalHolidayOn(DateTime(2026, 4, 21, 23, 59))?.name,
      'Tiradentes',
    );
  });

  test('dia comum não é feriado', () {
    expect(nationalHolidayOn(DateTime(2026, 4, 22)), isNull);
    expect(nationalHolidayOn(DateTime(2026, 9, 8)), isNull);
  });
}
