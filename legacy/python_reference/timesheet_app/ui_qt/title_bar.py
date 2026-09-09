"""Chrome superior da janela HoraFolio."""

from __future__ import annotations

from PySide6.QtCore import QPoint, QSize, Qt, Signal
from PySide6.QtWidgets import QHBoxLayout, QLabel, QPushButton, QWidget

from .theme import SPACE, scaled
from .widgets import make_line_icon


class TitleBar(QWidget):
    """Barra frameless compacta com marca, contexto e controles da janela."""

    settings_requested = Signal()
    shortcuts_requested = Signal()

    def __init__(self, title: str = "HoraFolio", parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("TitleBar")
        self._drag_offset: QPoint | None = None

        layout = QHBoxLayout(self)
        layout.setContentsMargins(scaled(SPACE["md"]), 0, scaled(SPACE["xs"]), 0)
        layout.setSpacing(scaled(SPACE["sm"]))

        brand = QLabel("HF")
        brand.setObjectName("BrandMark")
        brand.setAlignment(Qt.AlignCenter)
        brand.setFixedSize(scaled(28), scaled(24))
        layout.addWidget(brand, 0, Qt.AlignVCenter)

        self.title_label = QLabel(title)
        self.title_label.setObjectName("TitleBarText")
        layout.addWidget(self.title_label, 0, Qt.AlignVCenter)

        separator = QLabel("/")
        separator.setObjectName("TitleBarContext")
        layout.addWidget(separator, 0, Qt.AlignVCenter)
        self.context_label = QLabel("Entrada")
        self.context_label.setObjectName("TitleBarContext")
        layout.addWidget(self.context_label, 0, Qt.AlignVCenter)
        layout.addStretch(1)

        self.btn_shortcuts = self._window_button("info", "Atalhos · Ctrl+/", "TitleBarBtn")
        self.btn_shortcuts.clicked.connect(self.shortcuts_requested.emit)
        self.btn_settings = self._window_button("settings", "Preferências · Ctrl+,", "TitleBarBtn")
        self.btn_settings.clicked.connect(self.settings_requested.emit)
        self.btn_min = self._window_button("minimize", "Minimizar", "TitleBarBtn")
        self.btn_min.clicked.connect(self._minimize)
        self.btn_max = self._window_button("maximize", "Maximizar", "TitleBarBtn")
        self.btn_max.clicked.connect(self._toggle_maximize)
        self.btn_close = self._window_button("close", "Fechar", "TitleBarBtnClose")
        self.btn_close.clicked.connect(self._close_window)

        for button in (self.btn_shortcuts, self.btn_settings, self.btn_min, self.btn_max, self.btn_close):
            layout.addWidget(button, 0, Qt.AlignVCenter)

        self.setFixedHeight(scaled(40))

    def _window_button(self, icon: str, tooltip: str, object_name: str) -> QPushButton:
        button = QPushButton("")
        button.setObjectName(object_name)
        button.setToolTip(tooltip)
        button.setAccessibleName(tooltip.split(" · ", 1)[0])
        button.setIcon(make_line_icon(icon))
        button.setIconSize(QSize(scaled(16), scaled(16)))
        button.setFixedSize(scaled(38), scaled(30))
        return button

    def set_title(self, text: str) -> None:
        """Compatibilidade: o título principal agora é a marca e o texto vira contexto."""
        self.set_context(text)

    def set_context(self, text: str) -> None:
        normalized = text.replace("Timesheet — ", "").strip()
        self.context_label.setText(normalized or "Entrada")

    def _window(self):
        return self.window()

    def _minimize(self) -> None:
        win = self._window()
        if win:
            win.showMinimized()

    def _toggle_maximize(self) -> None:
        win = self._window()
        if win is None:
            return
        if win.isMaximized():
            win.showNormal()
        else:
            win.showMaximized()
        self.sync_window_state()

    def sync_window_state(self) -> None:
        """Mantém ícone/tooltip corretos quando o SO altera o estado da janela."""
        win = self._window()
        maximized = bool(win and win.isMaximized())
        self.btn_max.setIcon(make_line_icon("restore" if maximized else "maximize"))
        self.btn_max.setToolTip("Restaurar" if maximized else "Maximizar")
        self.btn_max.setAccessibleName("Restaurar" if maximized else "Maximizar")

    def _close_window(self) -> None:
        win = self._window()
        if win:
            win.close()

    def mousePressEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.LeftButton:
            win = self._window()
            if win and not win.isMaximized():
                self._drag_offset = event.globalPosition().toPoint() - win.frameGeometry().topLeft()
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event) -> None:  # noqa: N802
        if event.buttons() & Qt.LeftButton and self._drag_offset is not None:
            win = self._window()
            if win and not win.isMaximized():
                win.move(event.globalPosition().toPoint() - self._drag_offset)
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event) -> None:  # noqa: N802
        self._drag_offset = None
        super().mouseReleaseEvent(event)

    def mouseDoubleClickEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.LeftButton:
            self._toggle_maximize()
            event.accept()
            return
        super().mouseDoubleClickEvent(event)
