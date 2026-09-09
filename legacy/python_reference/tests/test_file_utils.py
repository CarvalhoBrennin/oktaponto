from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from timesheet_app.file_utils import atomic_write_via_path


class AtomicWriteTest(unittest.TestCase):
    def test_failure_does_not_replace_existing_target(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "state.json"
            target.write_text("anterior", encoding="utf-8")

            def broken_writer(temp_path: Path) -> None:
                temp_path.write_text("parcial", encoding="utf-8")
                raise OSError("falha")

            with self.assertRaises(OSError):
                atomic_write_via_path(target, broken_writer)

            self.assertEqual(target.read_text(encoding="utf-8"), "anterior")
            self.assertEqual(list(Path(tmp).glob(".*.tmp*")), [])

    def test_success_flushes_file_before_atomic_replace(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "state.json"

            def writer(temp_path: Path) -> None:
                temp_path.write_text("novo", encoding="utf-8")

            with patch("timesheet_app.file_utils.os.fsync") as fsync:
                atomic_write_via_path(target, writer)

            self.assertEqual(target.read_text(encoding="utf-8"), "novo")
            self.assertGreaterEqual(fsync.call_count, 1)


if __name__ == "__main__":
    unittest.main()