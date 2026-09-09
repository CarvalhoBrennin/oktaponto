from __future__ import annotations

import unittest
from datetime import date
from itertools import permutations

from timesheet_app.models import TimesheetRecord
from timesheet_app.automation import is_review_exception
from timesheet_app.parser.banco_horas_parser import consolidate_records


class ConsolidationTest(unittest.TestCase):
    def test_duplicate_same_value(self) -> None:
        records = [
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 429, True, source_file="a.png"),
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 429, True, source_file="b.png"),
        ]
        result = consolidate_records(records)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].worked_minutes, 429)

    def test_conflict_marks_review_and_keeps_larger(self) -> None:
        records = [
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 429, True, source_file="a.png"),
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 430, True, source_file="b.png"),
        ]
        result = consolidate_records(records)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].worked_minutes, 430)
        self.assertEqual(result[0].status, "revisar")
        self.assertFalse(result[0].include)

    def test_identical_duplicate_preserves_manual_edit_metadata(self) -> None:
        records = [
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 430, True, "ok", source_file="ocr.png"),
            TimesheetRecord(
                date(2026, 6, 9), "Terça-feira", 430, True, "editado",
                source_file="manual", atividade="Deploy",
            ),
        ]
        result = consolidate_records(records)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].status, "editado")
        self.assertEqual(result[0].atividade, "Deploy")
        self.assertEqual(result[0].source_file, "manual")
        self.assertTrue(any("ocr.png" in note for note in result[0].notes))

    def test_conflict_keeps_edited_status(self) -> None:
        records = [
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 429, True, "editado", source_file="a.png"),
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 430, True, "revisar", source_file="b.png"),
        ]
        result = consolidate_records(records)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].status, "editado")
        self.assertTrue(result[0].include)

    def test_manual_edit_can_remain_explicitly_ignored(self) -> None:
        records = [
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 429, False, "editado", source_file="manual"),
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 430, True, "ok", source_file="ocr.png"),
        ]
        result = consolidate_records(records)
        self.assertEqual(result[0].worked_minutes, 429)
        self.assertEqual(result[0].status, "editado")
        self.assertFalse(result[0].include)


    def test_positive_ignored_decision_survives_later_conflicting_ocr(self) -> None:
        records = [
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 429, False, "ignorado", source_file="a.png"),
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 500, True, "ok", source_file="b.png"),
        ]
        result = consolidate_records(records)
        self.assertEqual(result[0].worked_minutes, 429)
        self.assertEqual(result[0].status, "editado")
        self.assertFalse(result[0].include)

    def test_confirming_ok_source_resolves_same_value_review_without_inheriting_low_confidence(self) -> None:
        records = [
            TimesheetRecord(
                date(2026, 6, 9), "Terça-feira", 429, False, "revisar",
                source_file="ocr.png", confidence=22.0,
                notes=["Confiança baixa no OCR do horário (22). Confira na tabela."],
            ),
            TimesheetRecord(
                date(2026, 6, 9), "Terça-feira", 429, True, "ok",
                source_file="espelho.xlsx", confidence=None,
            ),
        ]
        result = consolidate_records(records)
        self.assertEqual(result[0].status, "ok")
        self.assertTrue(result[0].include)
        self.assertIsNone(result[0].confidence)
        self.assertFalse(is_review_exception(result[0]))
        self.assertFalse(any("confiança baixa" in note.casefold() for note in result[0].notes))


    def test_confirming_ok_source_is_order_independent(self) -> None:
        good = TimesheetRecord(
            date(2026, 6, 9), "Terça-feira", 429, True, "ok",
            source_file="espelho.xlsx", confidence=None,
        )
        bad = TimesheetRecord(
            date(2026, 6, 9), "Terça-feira", 429, False, "revisar",
            source_file="ocr.png", confidence=22.0,
            notes=["Confiança baixa no OCR do horário (22). Confira na tabela."],
        )
        for records in ([bad, good], [good, bad]):
            result = consolidate_records(records)[0]
            self.assertEqual(result.status, "ok")
            self.assertEqual(result.source_file, "espelho.xlsx")
            self.assertFalse(is_review_exception(result))
            self.assertFalse(any("confiança baixa" in note.casefold() for note in result.notes))

    def test_later_manual_empty_activity_is_not_repopulated_from_older_manual(self) -> None:
        records = [
            TimesheetRecord(
                date(2026, 6, 9), "Terça-feira", 429, True, "editado",
                source_file="manual", atividade="Atividade antiga",
            ),
            TimesheetRecord(
                date(2026, 6, 9), "Terça-feira", 429, True, "editado",
                source_file="manual", atividade="",
            ),
        ]
        result = consolidate_records(records)[0]
        self.assertEqual(result.atividade, "")

    def test_later_manual_decision_wins_for_same_value(self) -> None:
        records = [
            TimesheetRecord(
                date(2026, 6, 9), "Terça-feira", 429, True, "editado",
                source_file="manual", atividade="Atividade antiga",
            ),
            TimesheetRecord(
                date(2026, 6, 9), "Terça-feira", 429, False, "editado",
                source_file="manual", atividade="Atividade nova",
            ),
        ]
        result = consolidate_records(records)
        self.assertFalse(result[0].include)
        self.assertEqual(result[0].atividade, "Atividade nova")

    def test_later_manual_decision_wins_for_conflicting_value(self) -> None:
        records = [
            TimesheetRecord(
                date(2026, 6, 9), "Terça-feira", 429, True, "editado", source_file="manual"
            ),
            TimesheetRecord(
                date(2026, 6, 9), "Terça-feira", 450, False, "editado", source_file="manual"
            ),
        ]
        result = consolidate_records(records)
        self.assertEqual(result[0].worked_minutes, 450)
        self.assertFalse(result[0].include)
        self.assertEqual(result[0].status, "editado")

    def test_same_value_preserves_existing_ignore_decision(self) -> None:
        records = [
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 429, False, "ignorado", source_file="a.png"),
            TimesheetRecord(date(2026, 6, 9), "Terça-feira", 429, True, "ok", source_file="b.png"),
        ]
        result = consolidate_records(records)
        self.assertFalse(result[0].include)
        self.assertEqual(result[0].status, "ignorado")

    def test_three_automatic_sources_with_conflict_are_order_independent(self) -> None:
        specs = [(480, "a.png"), (450, "b.png"), (480, "c.png")]
        outcomes = set()
        for order in permutations(specs):
            records = [
                TimesheetRecord(date(2026, 6, 9), "Terça-feira", minutes, True, "ok", source_file=source)
                for minutes, source in order
            ]
            result = consolidate_records(records)[0]
            outcomes.add((result.worked_minutes, result.status, result.include))
        self.assertEqual(outcomes, {(480, "revisar", False)})

    def test_consolidation_does_not_mutate_input_records(self) -> None:
        first = TimesheetRecord(
            date(2026, 6, 9), "Terça-feira", 480, True, "ok",
            source_file="a.png", notes=["nota original"],
        )
        second = TimesheetRecord(
            date(2026, 6, 9), "Terça-feira", 450, True, "ok",
            source_file="b.png",
        )
        result = consolidate_records([first, second])[0]
        self.assertEqual(result.status, "revisar")
        self.assertEqual(first.status, "ok")
        self.assertTrue(first.include)
        self.assertEqual(first.notes, ["nota original"])
        self.assertEqual(second.status, "ok")
        self.assertTrue(second.include)

    def test_matching_new_source_does_not_erase_an_unresolved_historical_conflict(self) -> None:
        prior_conflict = TimesheetRecord(
            date(2026, 6, 9), "Terça-feira", 480, False, "revisar",
            source_file="sessao",
            notes=[
                "Conflito entre fontes para a mesma data: 7:30 x 8:00. "
                "Valor maior mantido provisoriamente; revise antes de incluir."
            ],
        )
        matching = TimesheetRecord(
            date(2026, 6, 9), "Terça-feira", 480, True, "ok",
            source_file="novo.png",
        )
        result = consolidate_records([prior_conflict, matching])[0]
        self.assertEqual(result.status, "revisar")
        self.assertFalse(result.include)
        self.assertTrue(any("conflito" in note.casefold() for note in result.notes))
    def test_explicit_ignore_without_hours_survives_later_reimport(self) -> None:
        pending = TimesheetRecord(
            date(2026, 6, 8), "Segunda-feira", None, False, "revisar",
            source_file="ocr.png", notes=["Não foi possível localizar o valor de 'Trabalhou'."],
        )
        from timesheet_app.automation import apply_include_decision
        apply_include_decision(pending, False)
        self.assertTrue(pending.manual_decision)

        later = TimesheetRecord(
            date(2026, 6, 8), "Segunda-feira", 480, True, "ok", source_file="novo.png"
        )
        merged = consolidate_records([pending, later])
        self.assertEqual(len(merged), 1)
        self.assertFalse(merged[0].include)
        self.assertTrue(merged[0].manual_decision)
        self.assertEqual(merged[0].status, "editado")


    def test_nonfinite_confidence_does_not_make_automatic_merge_order_dependent(self) -> None:
        a = TimesheetRecord(
            date(2026, 6, 8), "Segunda-feira", 480, True, "ok",
            source_file="same.png", confidence=float("nan"), atividade="B",
        )
        b = TimesheetRecord(
            date(2026, 6, 8), "Segunda-feira", 480, True, "ok",
            source_file="same.png", confidence=90.0, atividade="A",
        )
        first = consolidate_records([a, b])[0]
        second = consolidate_records([b, a])[0]
        self.assertEqual(first.atividade, second.atividade)
        self.assertEqual(first.confidence, second.confidence)
        self.assertEqual(first.confidence, 90.0)



if __name__ == "__main__":
    unittest.main()
