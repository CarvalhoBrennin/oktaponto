from __future__ import annotations

import unittest

from timesheet_app.parser.banco_horas_parser import BancoHorasParser, consolidate_records, detect_missing_weekdays
from timesheet_app.parser.timeparse import find_time_candidates, parse_hhmm_token


SAMPLE_TEXT = """
Terça-Feira, 09/06/2026
Expediente (ajuste aprovado)
Pontos
09:13 13:21 14:27 17:28
Trabalhou Falta Saldo
7:09 -0:51 +80:26

Segunda-Feira, 08/06/2026
Expediente
Pontos
08:51 12:05 13:00 18:16
Trabalhou Extra Saldo
8:30 +0:30 +81:17

Domingo, 07/06/2026
Folga
Trabalhou Saldo
0:00 +80:47

Sexta-Feira, 12/06/2026
Expediente
Pontos
08:30 16:45 17:45 18:38
Trabalhou Extra Saldo
9:08 +1:08 +82:47
"""


class ParserTextTest(unittest.TestCase):
    def test_parse_sample_text(self) -> None:
        records = BancoHorasParser().parse_text(SAMPLE_TEXT, source_file="sample")
        records = consolidate_records(records)
        by_date = {r.data.strftime("%d/%m/%Y"): r for r in records}

        self.assertEqual(by_date["09/06/2026"].worked_minutes, 7 * 60 + 9)
        self.assertTrue(by_date["09/06/2026"].include)
        self.assertEqual(by_date["08/06/2026"].worked_minutes, 8 * 60 + 30)
        self.assertEqual(by_date["12/06/2026"].dia_semana, "Sexta-feira")
        self.assertFalse(by_date["07/06/2026"].include)

    def test_pontos_do_not_include_worked_total(self) -> None:
        text = """
Segunda-Feira, 08/06/2026
Expediente
Pontos
09:00 17:00
Trabalhou
8:00
"""
        record = BancoHorasParser().parse_text(text)[0]
        self.assertEqual(record.pontos, ["09:00", "17:00"])
        self.assertEqual(record.worked_minutes, 480)

    def test_common_lowercase_ocr_digit_confusions_are_normalized(self) -> None:
        self.assertEqual(parse_hhmm_token("i:3b"), 98)
        self.assertEqual(find_time_candidates("valor q8:3b"), [("q8:3b", 8 * 60 + 38)])

    def test_worked_above_24_hours_requires_review(self) -> None:
        text = """
Segunda-Feira, 08/06/2026
Expediente
Trabalhou
24:30
"""
        record = BancoHorasParser().parse_text(text)[0]
        self.assertEqual(record.worked_minutes, 24 * 60 + 30)
        self.assertEqual(record.status, "revisar")
        self.assertFalse(record.include)

    def test_missing_weekdays(self) -> None:
        records = consolidate_records(BancoHorasParser().parse_text(SAMPLE_TEXT, source_file="sample"))
        missing = [d.strftime("%d/%m/%Y") for d in detect_missing_weekdays(records)]
        self.assertIn("10/06/2026", missing)
        self.assertIn("11/06/2026", missing)

    def test_dotted_date_is_not_misread_as_clock_point(self) -> None:
        text = """
Segunda-feira 08.06.2026
Entrada 09:00
Saída 18:00
Trabalhou
8:00
"""
        record = BancoHorasParser().parse_text(text)[0]
        self.assertEqual(record.pontos, ["09:00", "18:00"])
        self.assertEqual(record.worked_minutes, 480)



if __name__ == "__main__":
    unittest.main()
