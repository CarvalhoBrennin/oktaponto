from __future__ import annotations

import tempfile
import unittest
from datetime import date
from pathlib import Path

from timesheet_app.automation import (
    analyze_records,
    apply_include_decision,
    group_records_by_month,
    is_review_exception,
    next_available_path,
    preferred_output_directory,
    reserve_available_path,
)
from timesheet_app.models import AutomationConfig, TimesheetRecord
from timesheet_app.parser.banco_horas_parser import detect_missing_weekdays


class AutomationTest(unittest.TestCase):
    def test_groups_only_eligible_records_by_month(self) -> None:
        records = [
            TimesheetRecord(date(2026, 6, 8), "Segunda-feira", 480, True),
            TimesheetRecord(date(2026, 7, 1), "Quarta-feira", 450, True),
            TimesheetRecord(date(2026, 7, 2), "Quinta-feira", 0, False, "ignorado"),
        ]
        grouped = group_records_by_month(records)
        self.assertEqual(list(grouped), [(2026, 6), (2026, 7)])
        self.assertEqual(len(grouped[(2026, 7)]), 1)

    def test_missing_weekdays_does_not_bridge_months(self) -> None:
        records = [
            TimesheetRecord(date(2026, 6, 29), "Segunda-feira", 480, True),
            TimesheetRecord(date(2026, 6, 30), "Terça-feira", 480, True),
            TimesheetRecord(date(2026, 7, 30), "Quinta-feira", 480, True),
            TimesheetRecord(date(2026, 7, 31), "Sexta-feira", 480, True),
        ]
        self.assertEqual(detect_missing_weekdays(records), [])

    def test_known_holiday_is_not_reported_as_missing(self) -> None:
        records = [
            TimesheetRecord(date(2026, 7, 8), "Quarta-feira", 480, True),
            TimesheetRecord(date(2026, 7, 9), "Quinta-feira", 0, False, "ignorado", tipo="Feriado"),
            TimesheetRecord(date(2026, 7, 10), "Sexta-feira", 480, True),
        ]
        self.assertEqual(detect_missing_weekdays(records), [])

    def test_report_flags_review_missing_and_suspicious(self) -> None:
        records = [
            TimesheetRecord(date(2026, 6, 8), "Segunda-feira", 480, True),
            TimesheetRecord(date(2026, 6, 10), "Quarta-feira", 17 * 60, True, "revisar"),
        ]
        report = analyze_records(records)
        self.assertEqual(report.review_count, 1)
        self.assertEqual(report.missing_weekdays, [date(2026, 6, 9)])
        self.assertEqual(report.suspicious_dates, [date(2026, 6, 10)])
        self.assertTrue(report.has_attention_items)


    def test_parser_note_that_explicitly_requests_check_is_pending(self) -> None:
        record = TimesheetRecord(
            date(2026, 6, 8), "Segunda-feira", 480, True, "ok",
            notes=["Extraído por texto bruto; confira na tabela."],
        )
        self.assertTrue(is_review_exception(record))

    def test_include_decision_resolves_conflict_as_manual_edit(self) -> None:
        record = TimesheetRecord(
            date(2026, 6, 8), "Segunda-feira", 480, False, "revisar",
            notes=["Conflito entre prints para a mesma data."],
        )
        apply_include_decision(record, True)
        self.assertTrue(record.include)
        self.assertEqual(record.status, "editado")
        self.assertFalse(is_review_exception(record))

    def test_reinclude_low_confidence_ignored_record_becomes_manual_edit(self) -> None:
        record = TimesheetRecord(
            date(2026, 6, 8), "Segunda-feira", 480, False, "ignorado", confidence=20.0
        )
        apply_include_decision(record, True)
        self.assertEqual(record.status, "editado")
        self.assertFalse(is_review_exception(record))

    def test_ignored_status_marked_include_is_inconsistent(self) -> None:
        record = TimesheetRecord(date(2026, 6, 8), "Segunda-feira", 480, True, "ignorado")
        self.assertTrue(is_review_exception(record))

    def test_manual_review_clears_stale_ocr_warning(self) -> None:
        record = TimesheetRecord(
            date(2026, 6, 8), "Segunda-feira", 480, True, "editado",
            confidence=31.0, notes=["Conflito entre prints para a mesma data."],
        )
        self.assertFalse(is_review_exception(record))
        self.assertEqual(analyze_records([record]).review_count, 0)

    def test_manually_ignored_low_confidence_record_is_not_a_pending_issue(self) -> None:
        record = TimesheetRecord(
            date(2026, 6, 8), "Segunda-feira", 480, False, "ignorado",
            confidence=20.0, manual_decision=True,
        )
        self.assertFalse(is_review_exception(record))

    def test_manual_record_marked_for_inclusion_without_hours_is_still_flagged(self) -> None:
        record = TimesheetRecord(date(2026, 6, 8), "Segunda-feira", None, True, "editado")
        self.assertTrue(is_review_exception(record))


    def test_invalid_positive_hours_never_count_as_eligible_and_are_pending(self) -> None:
        zero_ok = TimesheetRecord(date(2026, 6, 8), "Segunda-feira", 0, True, "ok")
        too_high = TimesheetRecord(date(2026, 6, 9), "Terça-feira", 24 * 60 + 1, True, "ok")
        for record in (zero_ok, too_high):
            self.assertFalse(record.eligible_for_excel())
            self.assertTrue(is_review_exception(record))
        report = analyze_records([zero_ok, too_high])
        self.assertEqual(report.included_count, 0)
        self.assertEqual(report.review_count, 2)

    def test_explicitly_ignored_invalid_value_does_not_reopen_pending(self) -> None:
        record = TimesheetRecord(date(2026, 6, 8), "Segunda-feira", 24 * 60 + 1, False, "ignorado")
        self.assertFalse(record.eligible_for_excel())
        self.assertFalse(is_review_exception(record))

    def test_runtime_type_corruption_is_not_treated_as_valid_minutes(self) -> None:
        for value in (True, 480.5, "480"):
            record = TimesheetRecord(date(2026, 6, 8), "Segunda-feira", value, True, "ok")  # type: ignore[arg-type]
            self.assertEqual(record.worked_hhmm, "")
            self.assertFalse(record.eligible_for_excel())
            self.assertTrue(is_review_exception(record))

    def test_next_available_path_never_overwrites(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            first = Path(tmp) / "timesheet.xlsx"
            first.write_bytes(b"x")
            second = next_available_path(first)
            self.assertEqual(second.name, "timesheet (2).xlsx")
            second.write_bytes(b"x")
            self.assertEqual(next_available_path(first).name, "timesheet (3).xlsx")

    def test_reserve_available_path_is_exclusive(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp) / "timesheet.xlsx"
            first = reserve_available_path(base)
            second = reserve_available_path(base)
            self.assertEqual(first.name, "timesheet.xlsx")
            self.assertEqual(second.name, "timesheet (2).xlsx")
            self.assertTrue(first.exists())
            self.assertTrue(second.exists())

    def test_configured_output_directory_has_priority(self) -> None:
        config = AutomationConfig(output_dir="~/meus-timesheets", last_output_dir="/tmp/old")
        self.assertEqual(preferred_output_directory(config), Path("~/meus-timesheets").expanduser())

    def test_low_confidence_automatic_zero_remains_pending_until_human_ignores(self) -> None:
        record = TimesheetRecord(
            date(2026, 6, 8), "Segunda-feira", 0, False, "ignorado",
            notes=["Confiança baixa no OCR do horário (31)."], confidence=31,
        )
        self.assertTrue(is_review_exception(record))
        apply_include_decision(record, False)
        self.assertTrue(record.manual_decision)
        self.assertFalse(is_review_exception(record))


    def test_unknown_runtime_status_is_pending_and_manual_decision_can_resolve_it(self) -> None:
        record = TimesheetRecord(date(2026, 6, 8), "Segunda-feira", 480, True, "corrompido")
        self.assertTrue(is_review_exception(record))
        apply_include_decision(record, True)
        self.assertEqual(record.status, "editado")
        self.assertTrue(record.manual_decision)
        self.assertFalse(is_review_exception(record))



if __name__ == "__main__":
    unittest.main()
