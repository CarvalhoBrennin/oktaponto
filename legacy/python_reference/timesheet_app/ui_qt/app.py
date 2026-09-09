"""Ponto de entrada da UI Qt."""

from __future__ import annotations

import sys

from PySide6.QtWidgets import QApplication

from .main_window import MainWindow
from .theme import apply_dark_theme


def run_app() -> int:
    app = QApplication.instance() or QApplication(sys.argv)
    app.setApplicationName("HoraFolio")
    app.setApplicationDisplayName("HoraFolio")
    app.setOrganizationName("HoraFolio")
    apply_dark_theme(app)
    window = MainWindow()
    window.show()
    return app.exec()
