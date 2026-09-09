from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable

from .file_utils import atomic_write_via_path
from .models import TimesheetRecord
from .settings import get_config_dir

SESSION_FILE_NAME = "session.json"
SESSION_SCHEMA_VERSION = 1


@dataclass(slots=True)
class SessionSnapshot:
    records: list[TimesheetRecord]
    image_paths: list[Path]
    current_step: int = 0
    updated_at: str = ""

    @property
    def is_empty(self) -> bool:
        return not self.records and not self.image_paths


def get_session_path() -> Path:
    return get_config_dir() / SESSION_FILE_NAME


def save_session(
    records: Iterable[TimesheetRecord],
    image_paths: Iterable[str | Path],
    current_step: int,
    path: str | Path | None = None,
) -> Path:
    target = Path(path) if path is not None else get_session_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": SESSION_SCHEMA_VERSION,
        "updated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "current_step": max(0, min(int(current_step), 2)),
        "image_paths": [str(Path(item)) for item in image_paths],
        "records": [record.to_dict() for record in records],
    }
    serialized = json.dumps(payload, ensure_ascii=False, indent=2)
    atomic_write_via_path(target, lambda tmp: tmp.write_text(serialized, encoding="utf-8"))
    return target


def load_session(path: str | Path | None = None) -> SessionSnapshot | None:
    try:
        target = Path(path) if path is not None else get_session_path()
    except OSError:
        return None
    if not target.exists():
        return None
    try:
        raw = json.loads(target.read_text(encoding="utf-8"))
        if not isinstance(raw, dict):
            return None
        data: dict[str, Any] = raw
        version = int(data.get("schema_version", 0))
        if version > SESSION_SCHEMA_VERSION:
            return None
        records_raw = data.get("records") or []
        images_raw = data.get("image_paths") or []
        if not isinstance(records_raw, list) or not isinstance(images_raw, list):
            return None
        records: list[TimesheetRecord] = []
        for item in records_raw:
            if not isinstance(item, dict):
                continue
            try:
                records.append(TimesheetRecord.from_dict(item))
            except (ValueError, TypeError, KeyError):
                # Uma entrada antiga/corrompida não deve descartar toda a sessão.
                continue
        image_paths = [Path(str(item)) for item in images_raw if isinstance(item, (str, Path))]
        try:
            current_step = max(0, min(int(data.get("current_step", 0)), 2))
        except (ValueError, TypeError):
            current_step = 0
        return SessionSnapshot(
            records=records,
            image_paths=image_paths,
            current_step=current_step,
            updated_at=str(data.get("updated_at") or ""),
        )
    except (OSError, ValueError, TypeError, KeyError, json.JSONDecodeError):
        return None


def clear_session(path: str | Path | None = None) -> None:
    target = Path(path) if path is not None else get_session_path()
    target.unlink(missing_ok=True)
