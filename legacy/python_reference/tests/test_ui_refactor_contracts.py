"""Contratos estáticos do refactor Qt.

Estes testes não importam PySide6 de propósito. Assim continuam úteis no CI e em
ambientes que validam apenas a camada de negócio, garantindo que a arquitetura
visual nova não seja perdida por acidente.
"""

from __future__ import annotations

import ast
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
UI_ROOT = ROOT / "timesheet_app" / "ui_qt"


def _source(relative: str) -> str:
    return (UI_ROOT / relative).read_text(encoding="utf-8")


class UiRefactorContractTests(unittest.TestCase):
    def test_all_qt_modules_are_valid_python(self) -> None:
        modules = sorted(UI_ROOT.rglob("*.py"))
        self.assertGreaterEqual(len(modules), 10)
        for path in modules:
            with self.subTest(path=path.relative_to(ROOT)):
                ast.parse(path.read_text(encoding="utf-8"), filename=str(path))

    def test_shell_uses_persistent_navigation_rail(self) -> None:
        source = _source("main_window.py")
        self.assertIn("NavigationRail", source)
        self.assertNotIn("StepHeader(", source)
        self.assertIn("_refresh_session_summary", source)
        self.assertIn("set_compact", source)

    def test_pages_share_the_new_visual_primitives(self) -> None:
        for page in ("pages/page_prints.py", "pages/page_review.py", "pages/page_export.py"):
            source = _source(page)
            with self.subTest(page=page):
                self.assertIn("PageHeader", source)
                self.assertIn("StateBanner", source)
                self.assertIn("set_compact_mode", source)

    def test_review_is_table_plus_contextual_inspector(self) -> None:
        source = _source("pages/page_review.py")
        self.assertIn('QSplitter(Qt.Horizontal)', source)
        self.assertIn('SectionCard("Detalhes"', source)
        self.assertIn('"Pendências", "issues"', source)
        self.assertIn('"Aprovar"', source)
        self.assertIn('"Ignorar"', source)
        self.assertIn("focus_search", source)

    def test_settings_no_longer_use_generic_tabs(self) -> None:
        source = _source("dialogs.py")
        self.assertIn("SettingsNavItem", source)
        self.assertIn("QStackedWidget", source)
        self.assertNotIn("QTabWidget", source)

    def test_image_viewer_has_safe_zoom_contract(self) -> None:
        source = _source("dialogs.py")
        self.assertIn("max_pixels = 10_000_000", source)
        self.assertIn("max_render_pixels = 16_000_000", source)
        self.assertIn('QPushButton("100%")', source)
        self.assertIn("Qt.ControlModifier", source)

    def test_design_system_defines_semantic_and_focus_states(self) -> None:
        source = _source("theme.py")
        for token in ("accent_soft", "success_soft", "warning_soft", "error_soft", "text_dim"):
            with self.subTest(token=token):
                self.assertIn(f'"{token}"', source)
        self.assertIn("QPushButton:focus", source)
        self.assertIn("QLineEdit:focus", source)
        self.assertIn("QToolTip", source)

    def test_keyboard_workflows_are_documented_in_code(self) -> None:
        main = _source("main_window.py")
        review = _source("pages/page_review.py")
        for shortcut in ("Ctrl+N", "Ctrl+/", "Ctrl+1", "Ctrl+2", "Ctrl+3", "Ctrl+O", "Ctrl+I", "Ctrl+F"):
            with self.subTest(shortcut=shortcut):
                self.assertIn(shortcut, main)
        for shortcut in ("Delete", "Ctrl+Return", "Ctrl+Backspace"):
            with self.subTest(shortcut=shortcut):
                self.assertIn(shortcut, review)

    def test_destructive_shortcuts_are_scoped_to_their_views(self) -> None:
        prints = _source("pages/page_prints.py")
        review = _source("pages/page_review.py")
        main = _source("main_window.py")
        self.assertIn("WidgetWithChildrenShortcut", prints)
        self.assertIn("WidgetWithChildrenShortcut", review)
        self.assertIn("WindowShortcut", main)
        self.assertNotIn("ApplicationShortcut", main)


if __name__ == "__main__":
    unittest.main()
