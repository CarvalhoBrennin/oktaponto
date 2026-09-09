from __future__ import annotations

import tempfile
import unittest
import json
from datetime import date
from pathlib import Path

from timesheet_app.models import TimesheetRecord
from timesheet_app.session_store import clear_session, load_session, save_session


class SessionStoreTest(unittest.TestCase):
    def test_roundtrip_preserves_records_images_and_step(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            session_path = Path(tmp) / "session.json"
            image = Path(tmp) / "print.png"
            image.write_bytes(b"fake")
            records = [
                TimesheetRecord(
                    date(2026, 9, 1), "Terça-feira", 480, True,
                    source_file=str(image), atividade="Implementação",
                    notes=["ok"], confidence=91.0,
                )
            ]
            save_session(records, [image], 1, path=session_path)
            restored = load_session(session_path)
            self.assertIsNotNone(restored)
            assert restored is not None
            self.assertEqual(restored.current_step, 1)
            self.assertEqual(restored.image_paths, [image])
            self.assertEqual(restored.records[0].atividade, "Implementação")
            self.assertEqual(restored.records[0].worked_minutes, 480)

    def test_corrupt_session_is_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "session.json"
            path.write_text("not-json", encoding="utf-8")
            self.assertIsNone(load_session(path))

    def test_non_object_session_is_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "session.json"
            path.write_text("[]", encoding="utf-8")
            self.assertIsNone(load_session(path))

    def test_wrong_collection_shapes_are_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "session.json"
            path.write_text(json.dumps({"records": "nao-lista", "image_paths": []}), encoding="utf-8")
            self.assertIsNone(load_session(path))

    def test_legacy_string_lists_and_boolean_are_coerced_safely(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "session.json"
            path.write_text(json.dumps({
                "schema_version": 1,
                "records": [{
                    "data": "2026-09-01",
                    "dia_semana": "Terça-feira",
                    "worked_minutes": 480,
                    "include": "false",
                    "notes": "nota antiga",
                    "pontos": "09:00",
                }],
                "image_paths": [],
            }), encoding="utf-8")
            restored = load_session(path)
            self.assertIsNotNone(restored)
            self.assertFalse(restored.records[0].include)
            self.assertEqual(restored.records[0].notes, ["nota antiga"])
            self.assertEqual(restored.records[0].pontos, ["09:00"])


    def test_corrupt_include_value_fails_closed_but_missing_include_keeps_legacy_default(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "session.json"
            path.write_text(json.dumps({
                "schema_version": 1,
                "records": [
                    {"data": "2026-09-01", "worked_minutes": 480, "include": "talvez"},
                    {"data": "2026-09-02", "worked_minutes": 480},
                    {"data": "2026-09-03", "worked_minutes": 480, "include": [1]},
                ],
                "image_paths": [],
            }), encoding="utf-8")
            restored = load_session(path)
            self.assertIsNotNone(restored)
            assert restored is not None
            self.assertFalse(restored.records[0].include)
            self.assertTrue(restored.records[1].include)
            self.assertFalse(restored.records[2].include)

    def test_corrupt_hours_are_salvaged_as_review_instead_of_exported(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "session.json"
            path.write_text(json.dumps({
                "schema_version": 1,
                "records": [{
                    "data": "2026-09-01",
                    "dia_semana": "Domingo",
                    "worked_minutes": "oito horas",
                    "include": True,
                    "status": "ok",
                }],
                "image_paths": [],
            }), encoding="utf-8")
            restored = load_session(path)
            self.assertIsNotNone(restored)
            assert restored is not None
            record = restored.records[0]
            self.assertIsNone(record.worked_minutes)
            self.assertFalse(record.include)
            self.assertEqual(record.status, "revisar")
            self.assertEqual(record.dia_semana, "Terça-feira")

    def test_unknown_status_is_normalized_to_review_and_fails_closed(self) -> None:
        record = TimesheetRecord.from_dict({
            "data": "2026-09-01",
            "worked_minutes": 480,
            "include": True,
            "status": "desconhecido",
        })
        self.assertEqual(record.status, "revisar")
        self.assertFalse(record.include)

    def test_unresolved_or_ignored_status_is_never_eligible_even_with_checked_flag(self) -> None:
        reviewing = TimesheetRecord(date(2026, 9, 1), "Terça-feira", 480, True, "revisar")
        ignored = TimesheetRecord(date(2026, 9, 2), "Quarta-feira", 480, True, "ignorado")
        approved = TimesheetRecord(date(2026, 9, 3), "Quinta-feira", 480, True, "editado")
        self.assertFalse(reviewing.eligible_for_excel())
        self.assertFalse(ignored.eligible_for_excel())
        self.assertTrue(approved.eligible_for_excel())

    def test_out_of_range_hours_and_confidence_fail_safely(self) -> None:
        record = TimesheetRecord.from_dict({
            "data": "2026-09-01",
            "worked_minutes": 1500,
            "include": True,
            "status": "ok",
            "confidence": float("nan"),
        })
        self.assertEqual(record.status, "revisar")
        self.assertFalse(record.include)
        self.assertIsNone(record.confidence)

    def test_fractional_or_nonfinite_minutes_do_not_get_truncated_into_valid_hours(self) -> None:
        fractional = TimesheetRecord.from_dict({
            "data": "2026-09-01",
            "worked_minutes": 480.9,
            "include": True,
            "status": "ok",
        })
        nonfinite = TimesheetRecord.from_dict({
            "data": "2026-09-02",
            "worked_minutes": float("inf"),
            "include": True,
            "status": "ok",
        })
        integral_float = TimesheetRecord.from_dict({
            "data": "2026-09-03",
            "worked_minutes": 480.0,
            "include": True,
            "status": "ok",
        })
        self.assertIsNone(fractional.worked_minutes)
        self.assertFalse(fractional.include)
        self.assertEqual(fractional.status, "revisar")
        self.assertIsNone(nonfinite.worked_minutes)
        self.assertFalse(nonfinite.include)
        self.assertEqual(integral_float.worked_minutes, 480)
        self.assertTrue(integral_float.eligible_for_excel())

    def test_non_text_metadata_is_not_stringified_into_exportable_content(self) -> None:
        record = TimesheetRecord.from_dict({
            "data": "2026-09-01",
            "worked_minutes": 480,
            "include": True,
            "status": "ok",
            "atividade": {"formula": "=1+1"},
            "source_file": ["print.png"],
            "tipo": 123,
        })
        self.assertEqual(record.atividade, "")
        self.assertEqual(record.source_file, "")
        self.assertEqual(record.tipo, "")

    def test_one_corrupt_record_does_not_discard_valid_records(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "session.json"
            path.write_text(json.dumps({
                "schema_version": 1,
                "current_step": "invalido",
                "records": [
                    {"data": "data-invalida", "worked_minutes": 480},
                    {
                        "data": "2026-09-02",
                        "dia_semana": "Quarta-feira",
                        "worked_minutes": 450,
                        "include": True,
                    },
                ],
                "image_paths": [],
            }), encoding="utf-8")
            restored = load_session(path)
            self.assertIsNotNone(restored)
            assert restored is not None
            self.assertEqual(restored.current_step, 0)
            self.assertEqual(len(restored.records), 1)
            self.assertEqual(restored.records[0].data.isoformat(), "2026-09-02")

    def test_clear_session(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "session.json"
            path.write_text("{}", encoding="utf-8")
            clear_session(path)
            self.assertFalse(path.exists())

    def test_manual_decision_round_trips_in_session(self) -> None:
        record = TimesheetRecord(
            date(2026, 6, 8), "Segunda-feira", None, False, "ignorado", manual_decision=True
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "session.json"
            save_session([record], [], 1, path)
            loaded = load_session(path)
        self.assertIsNotNone(loaded)
        assert loaded is not None
        self.assertTrue(loaded.records[0].manual_decision)


    def test_legacy_positive_ignored_record_is_migrated_as_manual_decision(self) -> None:
        payload = {
            "data": "2026-06-08",
            "dia_semana": "Segunda-feira",
            "worked_minutes": 480,
            "include": False,
            "status": "ignorado",
        }
        record = TimesheetRecord.from_dict(payload)
        self.assertTrue(record.manual_decision)



if __name__ == "__main__":
    unittest.main()
