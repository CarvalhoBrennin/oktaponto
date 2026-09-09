#!/usr/bin/env python3
"""Validate the frozen Drift/SQLite v1 schema contract without Flutter."""
from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path


def validate(path: Path) -> None:
    sql = path.read_text(encoding="utf-8")
    connection = sqlite3.connect(":memory:")
    try:
        connection.executescript(sql)
        tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
            )
        }
        expected_tables = {
            "work_days",
            "punches",
            "punch_audit",
            "profile_settings",
            "reminders",
        }
        if tables != expected_tables:
            raise SystemExit(f"schema tables mismatch: {sorted(tables)}")

        indexes = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'"
            )
        }
        if not {
            "idx_punches_local_date_time",
            "idx_punch_audit_punch",
        }.issubset(indexes):
            raise SystemExit(f"schema indexes mismatch: {sorted(indexes)}")

        now = 1_700_000_000_000
        connection.execute(
            "INSERT INTO work_days(local_date, include_in_timesheet, created_at_utc_ms, updated_at_utc_ms) "
            "VALUES (?, 1, ?, ?)",
            ("2026-09-01", now, now),
        )
        try:
            connection.execute(
                "INSERT INTO punches(local_date, occurred_at_utc_ms, utc_offset_min, kind, is_edited, "
                "created_at_utc_ms, updated_at_utc_ms) VALUES (?, ?, 0, 'invalid', 0, ?, ?)",
                ("2026-09-01", now, now, now),
            )
        except sqlite3.IntegrityError:
            pass
        else:
            raise SystemExit("invalid punch kind was accepted by schema v1")

        try:
            connection.execute(
                "INSERT INTO reminders(label, hour, minute, weekdays_mask, enabled) "
                "VALUES ('x', 99, 0, 1, 1)"
            )
        except sqlite3.IntegrityError:
            pass
        else:
            raise SystemExit("invalid reminder bounds were accepted by schema v1")
    finally:
        connection.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "schema",
        nargs="?",
        default="app/drift_schemas/schema_v1.sql",
        type=Path,
    )
    args = parser.parse_args()
    validate(args.schema)
    print("SQLite schema v1 contract: OK")
