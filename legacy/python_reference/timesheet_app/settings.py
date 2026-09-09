from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from .file_utils import atomic_write_via_path
from .models import AppSettings, AutomationConfig, ProfileConfig


APP_DIR_NAME = ".timesheet_banco_horas"
CONFIG_FILE_NAME = "config.json"


def get_config_dir() -> Path:
    path = Path.home() / APP_DIR_NAME
    path.mkdir(parents=True, exist_ok=True)
    return path


def get_config_path() -> Path:
    return get_config_dir() / CONFIG_FILE_NAME


def _as_bool(value: Any, default: bool) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return default
    if isinstance(value, str):
        normalized = value.strip().casefold()
        if normalized in {"1", "true", "sim", "yes", "on"}:
            return True
        if normalized in {"0", "false", "nao", "não", "no", "off"}:
            return False
        return default
    if isinstance(value, (int, float)) and value in {0, 1}:
        return bool(value)
    return default


def _as_text(value: Any, default: str = "") -> str:
    return value if isinstance(value, str) else default


def load_settings() -> AppSettings:
    try:
        path = get_config_path()
    except OSError:
        return AppSettings()
    if not path.exists():
        return AppSettings()

    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return AppSettings()

    if not isinstance(raw, dict):
        return AppSettings()
    data: dict[str, Any] = raw

    profile_raw = data.get("profile")
    profile_data = profile_raw if isinstance(profile_raw, dict) else {}
    profile = ProfileConfig(
        colaborador=_as_text(profile_data.get("colaborador"), "").strip() or "Brenno C. Torquato",
        cargo=_as_text(profile_data.get("cargo"), "").strip() or "Desenvolvedor Jr",
        modalidade=_as_text(profile_data.get("modalidade"), "").strip() or "Presencial",
        atividade_padrao=_as_text(profile_data.get("atividade_padrao"), "").strip(),
    )

    automation_raw = data.get("automation")
    automation_data = automation_raw if isinstance(automation_raw, dict) else {}
    defaults = AutomationConfig()
    autosave_session = _as_bool(automation_data.get("autosave_session"), defaults.autosave_session)
    # Não existe salvamento manual de sessão: recuperar sem autosave só faria
    # uma configuração antiga reaparecer indefinidamente.
    restore_session = autosave_session and _as_bool(
        automation_data.get("restore_session"), defaults.restore_session
    )
    automation = AutomationConfig(
        autosave_session=autosave_session,
        restore_session=restore_session,
        focus_review_issues=_as_bool(automation_data.get("focus_review_issues"), defaults.focus_review_issues),
        auto_start_ocr=_as_bool(automation_data.get("auto_start_ocr"), defaults.auto_start_ocr),
        recursive_folder_import=_as_bool(
            automation_data.get("recursive_folder_import"), defaults.recursive_folder_import
        ),
        open_output_folder=_as_bool(automation_data.get("open_output_folder"), defaults.open_output_folder),
        output_dir=_as_text(automation_data.get("output_dir"), "").strip(),
        last_input_dir=_as_text(automation_data.get("last_input_dir"), "").strip(),
        last_output_dir=_as_text(automation_data.get("last_output_dir"), "").strip(),
    )

    return AppSettings(
        tesseract_cmd=_as_text(data.get("tesseract_cmd"), "").strip(),
        tesseract_lang=_as_text(data.get("tesseract_lang"), "").strip() or "por+eng",
        profile=profile,
        automation=automation,
    )


def save_settings(settings: AppSettings) -> None:
    path = get_config_path()
    payload = json.dumps(asdict(settings), ensure_ascii=False, indent=2)
    atomic_write_via_path(path, lambda tmp: tmp.write_text(payload, encoding="utf-8"))
