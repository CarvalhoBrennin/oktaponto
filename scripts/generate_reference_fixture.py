#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGACY = ROOT / "legacy" / "python_reference"
sys.path.insert(0, str(LEGACY))

from timesheet_app.constants import dia_semana_pt  # noqa: E402
from timesheet_app.excel.generator import generate_timesheet_xlsx  # noqa: E402
from timesheet_app.models import ProfileConfig, TimesheetRecord  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    payload = json.loads(Path(args.fixture).read_text(encoding="utf-8"))
    profile_data = payload["profile"]
    profile = ProfileConfig(
        colaborador=profile_data["employee_name"],
        cargo=profile_data["job_title"],
        modalidade=profile_data["work_mode"],
        atividade_padrao=profile_data["default_activity"],
    )
    records = []
    for item in payload["days"]:
        d = date.fromisoformat(item["date"])
        records.append(
            TimesheetRecord(
                data=d,
                dia_semana=dia_semana_pt(d),
                worked_minutes=int(item["worked_minutes"]),
                include=bool(item.get("include", True)),
                status="ok",
                atividade=str(item.get("activity", "")),
            )
        )
    generate_timesheet_xlsx(records, Path(args.output), profile=profile)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
