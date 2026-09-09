from __future__ import annotations

import logging
import os
import tempfile
import time
import unittest
from pathlib import Path

from timesheet_app.audit_log import (
    AuditFormatter,
    _new_log_path,
    get_logger,
    rotate_logs,
    setup_audit_logging,
    shutdown_audit_logging,
)


class AuditLogTests(unittest.TestCase):
    def setUp(self) -> None:
        shutdown_audit_logging()

    def tearDown(self) -> None:
        shutdown_audit_logging()

    def test_formatter_structure(self) -> None:
        record = logging.LogRecord(
            name="timesheet",
            level=logging.INFO,
            pathname=__file__,
            lineno=1,
            msg="mensagem de teste",
            args=(),
            exc_info=None,
        )
        record.component = "teste"
        formatted = AuditFormatter().format(record)
        self.assertRegex(formatted, r"^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[INFO\] \[teste\] mensagem de teste$")

    def test_formatter_maps_warning_to_warn(self) -> None:
        record = logging.LogRecord(
            name="timesheet",
            level=logging.WARNING,
            pathname=__file__,
            lineno=1,
            msg="aviso",
            args=(),
            exc_info=None,
        )
        record.component = "teste"
        formatted = AuditFormatter().format(record)
        self.assertIn("[WARN]", formatted)

    def test_rotate_logs_deletes_older_than_previous(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            logs_dir = Path(tmp)
            now = time.time()
            oldest = logs_dir / "log_2026-01-01_10-00-00.log"
            middle = logs_dir / "log_2026-01-02_10-00-00.log"
            newest = logs_dir / "log_2026-01-03_10-00-00.log"
            for index, path in enumerate((oldest, middle, newest)):
                path.write_text("log", encoding="utf-8")
                os.utime(path, (now + index, now + index))

            new_log = rotate_logs(logs_dir)
            remaining = sorted(logs_dir.glob("log_*.log"), key=lambda p: p.stat().st_mtime)

            self.assertEqual(len(remaining), 2)
            self.assertFalse(oldest.exists())
            self.assertFalse(middle.exists())
            self.assertTrue(newest.exists())
            self.assertTrue(new_log.exists())

    def test_setup_keeps_at_most_two_log_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            logs_dir = Path(tmp)
            first_log = setup_audit_logging(logs_dir)
            self.assertEqual(len(list(logs_dir.glob("log_*.log"))), 1)

            shutdown_audit_logging()
            time.sleep(1.1)
            setup_audit_logging(logs_dir)
            self.assertEqual(len(list(logs_dir.glob("log_*.log"))), 2)

            shutdown_audit_logging()
            time.sleep(1.1)
            setup_audit_logging(logs_dir)
            self.assertEqual(len(list(logs_dir.glob("log_*.log"))), 2)
            self.assertFalse(first_log.exists())

            shutdown_audit_logging()

    def test_logger_writes_structured_entry(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            logs_dir = Path(tmp)
            log_file = setup_audit_logging(logs_dir)
            get_logger("negocio").info("evento registrado")
            shutdown_audit_logging()

            content = log_file.read_text(encoding="utf-8")
            self.assertIn("[INFO] [negocio] evento registrado", content)

    def test_new_log_path_reserves_unique_name_immediately(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            logs_dir = Path(tmp)
            first = _new_log_path(logs_dir)
            second = _new_log_path(logs_dir)
            self.assertNotEqual(first, second)
            self.assertTrue(first.exists())
            self.assertTrue(second.exists())

    def test_rotation_does_not_fail_if_an_old_log_is_locked(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            logs_dir = Path(tmp)
            for index in range(3):
                path = logs_dir / f"log_2026-01-0{index + 1}_10-00-00.log"
                path.write_text("log", encoding="utf-8")
                os.utime(path, (index + 1, index + 1))

            original_unlink = Path.unlink

            def maybe_locked(path: Path, *args, **kwargs):
                if path.name == "log_2026-01-01_10-00-00.log":
                    raise PermissionError("arquivo em uso")
                return original_unlink(path, *args, **kwargs)

            from unittest.mock import patch
            with patch.object(Path, "unlink", new=maybe_locked):
                new_log = rotate_logs(logs_dir)

            self.assertTrue(new_log.exists())
