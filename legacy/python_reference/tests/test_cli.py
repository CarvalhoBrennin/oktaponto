from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from timesheet_app.cli import main
from timesheet_app.ocr.engine import OcrError


MULTI_MONTH_TEXT = """
Segunda-Feira, 08/06/2026
Expediente
Trabalhou
8:00

Quarta-Feira, 01/07/2026
Expediente
Trabalhou
7:30
"""


class CliIntegrationTest(unittest.TestCase):
    def _run(self, argv: list[str]) -> tuple[int, str, str]:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with patch("timesheet_app.cli.setup_audit_logging"), \
             patch("timesheet_app.cli.install_exception_hook"), \
             patch("timesheet_app.cli.shutdown_audit_logging"), \
             patch("timesheet_app.cli.get_logger"), \
             contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            code = main(argv)
        return code, stdout.getvalue(), stderr.getvalue()

    def test_output_dir_generates_one_file_per_month(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            text = root / "ocr.txt"
            text.write_text(MULTI_MONTH_TEXT, encoding="utf-8")
            output_dir = root / "out"
            code, stdout, stderr = self._run([
                "--ocr-text", str(text), "--output-dir", str(output_dir),
            ])
            self.assertEqual(code, 0, stderr)
            self.assertEqual(len(list(output_dir.glob("*.xlsx"))), 2)
            self.assertIn("Arquivo gerado:", stdout)

    def test_single_output_rejects_multiple_months_without_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            text = root / "ocr.txt"
            text.write_text(MULTI_MONTH_TEXT, encoding="utf-8")
            code, _stdout, stderr = self._run([
                "--ocr-text", str(text), "--output", str(root / "timesheet.xlsx"),
            ])
            self.assertEqual(code, 1)
            self.assertIn("mais de um mês", stderr)
            self.assertNotIn("Traceback", stderr)

    def test_missing_input_file_returns_friendly_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "timesheet.xlsx"
            code, _stdout, stderr = self._run([
                "--ocr-text", str(Path(tmp) / "nao-existe.txt"), "--output", str(output),
            ])
            self.assertEqual(code, 1)
            self.assertIn("Erro:", stderr)
            self.assertNotIn("Traceback", stderr)

    def test_bad_image_does_not_discard_valid_text_input(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            text = root / "ocr.txt"
            text.write_text(MULTI_MONTH_TEXT, encoding="utf-8")
            output_dir = root / "out"
            with patch("timesheet_app.cli.TesseractOcrEngine") as engine_cls:
                engine_cls.return_value.read_image.side_effect = OcrError("imagem inválida")
                code, stdout, stderr = self._run([
                    "--images", str(root / "ruim.png"),
                    "--ocr-text", str(text),
                    "--output-dir", str(output_dir),
                ])
            self.assertEqual(code, 0, stderr)
            self.assertEqual(len(list(output_dir.glob("*.xlsx"))), 2)
            self.assertIn("Aviso:", stderr)
            self.assertIn("Arquivo gerado:", stdout)

    def test_all_failed_images_return_error_instead_of_empty_success(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with patch("timesheet_app.cli.TesseractOcrEngine") as engine_cls:
                engine_cls.return_value.read_image.side_effect = OcrError("imagem inválida")
                code, _stdout, stderr = self._run([
                    "--images", str(root / "ruim.png"),
                    "--output", str(root / "out.xlsx"),
                ])
            self.assertEqual(code, 1)
            self.assertIn("falharam no OCR", stderr)

    def test_valid_input_with_no_recognized_records_is_processing_error_not_missing_input(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            text = Path(tmp) / "empty.txt"
            text.write_text("texto sem data nem horas", encoding="utf-8")
            output = Path(tmp) / "out.xlsx"
            err = io.StringIO()
            with contextlib.redirect_stderr(err):
                code = main(["--ocr-text", str(text), "--output", str(output)])
        self.assertEqual(code, 1)
        self.assertIn("Nenhum registro foi reconhecido", err.getvalue())



if __name__ == "__main__":
    unittest.main()
