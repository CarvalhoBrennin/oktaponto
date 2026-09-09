from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from timesheet_app.ocr.engine import (
    OcrError, TesseractOcrEngine, _parse_tsv, _run_tesseract,
    check_tesseract, normalize_tesseract_lang,
)


TSV_WITH_WORDS = "\n".join([
    "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
    "5\t1\t1\t1\t1\t1\t10\t10\t100\t20\t95\tTrabalhou",
    "5\t1\t1\t1\t2\t1\t10\t40\t50\t20\t90\t8:00",
])


class OcrEngineTest(unittest.TestCase):
    def test_successful_tsv_uses_single_tesseract_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            prepared = Path(tmp) / "prepared.png"
            prepared.write_bytes(b"x")
            with patch("timesheet_app.ocr.engine.resolve_tesseract_cmd", return_value="tesseract"), \
                 patch("timesheet_app.ocr.engine.prepare_for_ocr", return_value=prepared), \
                 patch("timesheet_app.ocr.engine._run_tesseract", return_value=TSV_WITH_WORDS) as run:
                result = TesseractOcrEngine().read_image("original.png", keep_debug_image=True)

            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args[-1], "tsv")
            self.assertEqual(len(result.words), 2)
            self.assertIn("Trabalhou", result.text)

    def test_empty_tsv_falls_back_to_raw_text(self) -> None:
        empty_tsv = "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n"
        with tempfile.TemporaryDirectory() as tmp:
            prepared = Path(tmp) / "prepared.png"
            prepared.write_bytes(b"x")
            with patch("timesheet_app.ocr.engine.resolve_tesseract_cmd", return_value="tesseract"), \
                 patch("timesheet_app.ocr.engine.prepare_for_ocr", return_value=prepared), \
                 patch("timesheet_app.ocr.engine._run_tesseract", side_effect=[empty_tsv, "Trabalhou\n8:00"]) as run:
                result = TesseractOcrEngine().read_image("original.png", keep_debug_image=True)

            self.assertEqual(run.call_count, 2)
            self.assertEqual(result.text, "Trabalhou\n8:00")
            self.assertTrue(result.warnings)


    def test_timeout_does_not_retry_as_language_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            prepared = Path(tmp) / "prepared.png"
            prepared.write_bytes(b"x")
            with patch("timesheet_app.ocr.engine.resolve_tesseract_cmd", return_value="tesseract"), \
                 patch("timesheet_app.ocr.engine.prepare_for_ocr", return_value=prepared), \
                 patch("timesheet_app.ocr.engine._run_tesseract", side_effect=OcrError("O OCR excedeu 60 segundos.")) as run:
                with self.assertRaisesRegex(OcrError, "excedeu 60 segundos"):
                    TesseractOcrEngine(lang="por+eng").read_image("original.png", keep_debug_image=True)
            self.assertEqual(run.call_count, 1)

    def test_missing_portuguese_language_retries_once_with_english(self) -> None:
        language_error = OcrError("Error opening data file por.traineddata; Failed loading language 'por'")
        with tempfile.TemporaryDirectory() as tmp:
            prepared = Path(tmp) / "prepared.png"
            prepared.write_bytes(b"x")
            with patch("timesheet_app.ocr.engine.resolve_tesseract_cmd", return_value="tesseract"), \
                 patch("timesheet_app.ocr.engine.prepare_for_ocr", return_value=prepared), \
                 patch("timesheet_app.ocr.engine._run_tesseract", side_effect=[language_error, TSV_WITH_WORDS]) as run:
                result = TesseractOcrEngine(lang="por+eng").read_image("original.png", keep_debug_image=True)
            self.assertEqual(run.call_count, 2)
            self.assertEqual(run.call_args_list[1].args[-2:], ("eng", "tsv"))
            self.assertTrue(any("idioma português" in warning for warning in result.warnings))


    def test_language_spec_is_normalized_before_running(self) -> None:
        with patch("timesheet_app.ocr.engine.resolve_tesseract_cmd", return_value="tesseract"):
            self.assertEqual(TesseractOcrEngine(lang=" por + eng ").lang, "por+eng")
            self.assertEqual(TesseractOcrEngine(lang="   ").lang, "por+eng")
            self.assertEqual(TesseractOcrEngine(lang="por++eng+por").lang, "por+eng")
        self.assertEqual(normalize_tesseract_lang(" eng + por "), "eng+por")

    def test_malformed_tsv_numeric_fields_are_skipped_instead_of_crashing(self) -> None:
        header = "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n"
        bad_inf = "5\t1\t1\t1\t1\t1\tinf\t10\t20\t20\t90\tHora\n"
        bad_nan = "5\t1\t1\t1\t1\t1\t10\t10\t20\t20\tnan\tHora\n"
        bad_width = "5\t1\t1\t1\t1\t1\t10\t10\t-5\t20\t90\tHora\n"
        good = "5\t1\t1\t1\t1\t1\t10\t10\t20\t20\t150\tOk\n"
        words = _parse_tsv(header + bad_inf + bad_nan + bad_width + good)
        self.assertEqual(len(words), 1)
        self.assertEqual(words[0].text, "Ok")
        self.assertEqual(words[0].confidence, 100.0)

    def test_fractional_tsv_geometry_is_rejected_instead_of_truncated(self) -> None:
        header = "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n"
        fractional = "5\t1\t1\t1\t1\t1\t10.9\t10\t20\t20\t90\tRuim\n"
        good = "5\t1\t1\t1\t1\t1\t10\t10\t20\t20\t90\tOk\n"
        words = _parse_tsv(header + fractional + good)
        self.assertEqual([word.text for word in words], ["Ok"])

    def test_timeout_is_wrapped_as_ocr_error(self) -> None:
        with patch("timesheet_app.ocr.engine.subprocess.run", side_effect=subprocess.TimeoutExpired("tesseract", 60)):
            with self.assertRaisesRegex(OcrError, "excedeu 60 segundos"):
                _run_tesseract("tesseract", Path("print.png"), "eng", "tsv")


class TesseractHealthCheckTest(unittest.TestCase):
    def test_configured_language_is_verified(self) -> None:
        version = subprocess.CompletedProcess(["tesseract", "--version"], 0, "tesseract 5.0\n", "")
        languages = subprocess.CompletedProcess(
            ["tesseract", "--list-langs"], 0,
            "List of available languages in /tmp (1):\neng\n", "",
        )
        with patch("timesheet_app.ocr.engine.resolve_tesseract_cmd", return_value="tesseract"), \
             patch("timesheet_app.ocr.engine.subprocess.run", side_effect=[version, languages]):
            ok, message = check_tesseract("", "spa")
        self.assertFalse(ok)
        self.assertIn("spa", message)


    def test_health_check_normalizes_whitespace_in_language_spec(self) -> None:
        version = subprocess.CompletedProcess(["tesseract", "--version"], 0, "tesseract 5.0\n", "")
        languages = subprocess.CompletedProcess(
            ["tesseract", "--list-langs"], 0,
            "List of available languages in /tmp (2):\npor\neng\n", "",
        )
        with patch("timesheet_app.ocr.engine.resolve_tesseract_cmd", return_value="tesseract"), \
             patch("timesheet_app.ocr.engine.subprocess.run", side_effect=[version, languages]):
            ok, message = check_tesseract("", " por + eng ")
        self.assertTrue(ok)
        self.assertIn("por+eng", message)

    def test_missing_portuguese_reports_supported_english_fallback(self) -> None:
        version = subprocess.CompletedProcess(["tesseract", "--version"], 0, "tesseract 5.0\n", "")
        languages = subprocess.CompletedProcess(
            ["tesseract", "--list-langs"], 0,
            "List of available languages in /tmp (1):\neng\n", "",
        )
        with patch("timesheet_app.ocr.engine.resolve_tesseract_cmd", return_value="tesseract"), \
             patch("timesheet_app.ocr.engine.subprocess.run", side_effect=[version, languages]):
            ok, message = check_tesseract("", "por+eng")
        self.assertTrue(ok)
        self.assertIn("fallback", message)


if __name__ == "__main__":
    unittest.main()