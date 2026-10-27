from __future__ import annotations

import json
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from timesheet_app.models import AppSettings, AutomationConfig, ProfileConfig
from timesheet_app.settings import load_settings, save_settings


class SettingsTest(unittest.TestCase):
    def test_loads_legacy_config_with_new_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.json"
            path.write_text(json.dumps({
                "tesseract_cmd": "tesseract",
                "profile": {"colaborador": "Pessoa", "cargo": "Dev", "modalidade": "Remoto"},
            }), encoding="utf-8")
            with patch("timesheet_app.settings.get_config_path", return_value=path):
                settings = load_settings()
            self.assertEqual(settings.profile.colaborador, "Pessoa")
            self.assertEqual(settings.profile.atividade_padrao, "")
            self.assertTrue(settings.automation.autosave_session)
            self.assertTrue(settings.automation.restore_session)


    def test_unavailable_config_directory_falls_back_to_defaults(self) -> None:
        with patch("timesheet_app.settings.get_config_path", side_effect=OSError("sem permissao")):
            settings = load_settings()
        self.assertEqual(settings.tesseract_lang, "por+eng")
        self.assertTrue(settings.automation.autosave_session)

    def test_restore_is_disabled_when_autosave_is_disabled(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.json"
            path.write_text(json.dumps({
                "automation": {"autosave_session": False, "restore_session": True},
            }), encoding="utf-8")
            with patch("timesheet_app.settings.get_config_path", return_value=path):
                loaded = load_settings()
            self.assertFalse(loaded.automation.autosave_session)
            self.assertFalse(loaded.automation.restore_session)

    def test_roundtrip_new_settings(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.json"
            settings = AppSettings(
                tesseract_cmd="x",
                tesseract_lang="por",
                profile=ProfileConfig("Pessoa", "Dev", "Híbrido", "Projeto X"),
                automation=AutomationConfig(
                    autosave_session=False,
                    restore_session=False,
                    output_dir="/tmp/timesheets",
                    last_input_dir="/tmp/in",
                ),
            )
            with patch("timesheet_app.settings.get_config_path", return_value=path):
                save_settings(settings)
                loaded = load_settings()
            self.assertFalse(loaded.automation.autosave_session)
            self.assertFalse(loaded.automation.restore_session)
            self.assertEqual(loaded.automation.output_dir, "/tmp/timesheets")
            self.assertEqual(loaded.profile.atividade_padrao, "Projeto X")

    def test_invalid_json_shape_falls_back_to_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.json"
            path.write_text("[]", encoding="utf-8")
            with patch("timesheet_app.settings.get_config_path", return_value=path):
                loaded = load_settings()
            self.assertEqual(loaded.profile.colaborador, "")
            self.assertEqual(loaded.profile.cargo, "")
            self.assertEqual(loaded.profile.modalidade, "")

    def test_invalid_nested_shapes_and_unknown_boole_use_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.json"
            path.write_text(json.dumps({
                "profile": ["invalido"],
                "automation": {"autosave_session": "talvez", "restore_session": "false"},
            }), encoding="utf-8")
            with patch("timesheet_app.settings.get_config_path", return_value=path):
                loaded = load_settings()
            self.assertTrue(loaded.automation.autosave_session)
            self.assertFalse(loaded.automation.restore_session)


    def test_malformed_scalar_types_do_not_turn_into_truthy_flags_or_paths(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config_path = Path(tmp) / "config.json"
            config_path.write_text(json.dumps({
                "tesseract_cmd": {"bad": "path"},
                "tesseract_lang": ["por"],
                "profile": {"colaborador": ["nome"], "cargo": {"x": 1}},
                "automation": {
                    "autosave_session": [1],
                    "output_dir": ["/tmp/out"],
                },
            }), encoding="utf-8")
            with patch("timesheet_app.settings.get_config_path", return_value=config_path):
                settings = load_settings()
        self.assertEqual(settings.tesseract_cmd, "")
        self.assertEqual(settings.tesseract_lang, "por+eng")
        self.assertEqual(settings.profile.colaborador, "")
        self.assertEqual(settings.profile.cargo, "")
        self.assertEqual(settings.profile.modalidade, "")
        self.assertTrue(settings.automation.autosave_session)  # padrão, não truthiness da lista
        self.assertEqual(settings.automation.output_dir, "")

    def test_text_and_path_settings_are_trimmed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config_path = Path(tmp) / "config.json"
            config_path.write_text(json.dumps({
                "tesseract_cmd": "  C:/OCR/tesseract.exe  ",
                "tesseract_lang": " por + eng ",
                "profile": {"atividade_padrao": "  Projeto Atlas  "},
                "automation": {
                    "output_dir": "  C:/saida  ",
                    "last_input_dir": "   ",
                    "last_output_dir": "  C:/ultima  ",
                },
            }), encoding="utf-8")
            with patch("timesheet_app.settings.get_config_path", return_value=config_path):
                settings = load_settings()
        self.assertEqual(settings.tesseract_cmd, "C:/OCR/tesseract.exe")
        self.assertEqual(settings.tesseract_lang, "por + eng")
        self.assertEqual(settings.profile.atividade_padrao, "Projeto Atlas")
        self.assertEqual(settings.automation.output_dir, "C:/saida")
        self.assertEqual(settings.automation.last_input_dir, "")
        self.assertEqual(settings.automation.last_output_dir, "C:/ultima")


if __name__ == "__main__":
    unittest.main()
