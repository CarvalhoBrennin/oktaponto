"""Componentes reutilizáveis da interface HoraFolio.

A intenção deste módulo é manter as páginas declarativas: componentes visuais,
ícones, navegação, banners, métricas e feedback ficam centralizados aqui.
"""

from __future__ import annotations

import math
from pathlib import Path

from PySide6.QtCore import QEasingCurve, QPoint, QPropertyAnimation, QRectF, QSize, Qt, QTimer, Signal
from PySide6.QtGui import QColor, QIcon, QPainter, QPainterPath, QPen, QPixmap
from PySide6.QtWidgets import (
    QFrame,
    QGraphicsOpacityEffect,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

from ..ocr.preprocess import is_supported_image
from .theme import COLORS, RADIUS, SPACE, scaled


# ---------------------------------------------------------------------------
# Vector line icons (sem assets externos)
# ---------------------------------------------------------------------------


def make_line_icon(name: str, color: str | None = None, size: int | None = None) -> QIcon:
    """Cria um ícone vetorial simples via QPainter.

    Evita dependência de fontes de ícones/emoji e mantém o executável portátil.
    """
    icon_size = size or scaled(18)
    pixmap = QPixmap(icon_size, icon_size)
    pixmap.fill(Qt.transparent)
    painter = QPainter(pixmap)
    painter.setRenderHint(QPainter.Antialiasing, True)
    pen = QPen(QColor(color or COLORS["text_muted"]), max(1, scaled(1.5)))
    pen.setCapStyle(Qt.RoundCap)
    pen.setJoinStyle(Qt.RoundJoin)
    painter.setPen(pen)
    painter.setBrush(Qt.NoBrush)
    s = float(icon_size)

    def line(x1: float, y1: float, x2: float, y2: float) -> None:
        painter.drawLine(int(s * x1), int(s * y1), int(s * x2), int(s * y2))

    if name == "settings":
        center = s * 0.5
        painter.drawEllipse(QRectF(s * 0.38, s * 0.38, s * 0.24, s * 0.24))
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            line(
                0.5 + math.cos(rad) * 0.31,
                0.5 + math.sin(rad) * 0.31,
                0.5 + math.cos(rad) * 0.43,
                0.5 + math.sin(rad) * 0.43,
            )
    elif name == "upload":
        path = QPainterPath()
        path.moveTo(s * 0.22, s * 0.70)
        path.lineTo(s * 0.22, s * 0.80)
        path.quadTo(s * 0.22, s * 0.86, s * 0.30, s * 0.86)
        path.lineTo(s * 0.70, s * 0.86)
        path.quadTo(s * 0.78, s * 0.86, s * 0.78, s * 0.80)
        path.lineTo(s * 0.78, s * 0.70)
        painter.drawPath(path)
        line(0.5, 0.18, 0.5, 0.66)
        line(0.5, 0.18, 0.34, 0.35)
        line(0.5, 0.18, 0.66, 0.35)
    elif name in {"file", "text", "spreadsheet"}:
        path = QPainterPath()
        path.moveTo(s * 0.27, s * 0.14)
        path.lineTo(s * 0.58, s * 0.14)
        path.lineTo(s * 0.76, s * 0.32)
        path.lineTo(s * 0.76, s * 0.86)
        path.lineTo(s * 0.27, s * 0.86)
        path.closeSubpath()
        painter.drawPath(path)
        line(0.58, 0.14, 0.58, 0.32)
        line(0.58, 0.32, 0.76, 0.32)
        if name == "text":
            line(0.36, 0.48, 0.66, 0.48)
            line(0.36, 0.61, 0.66, 0.61)
            line(0.36, 0.74, 0.57, 0.74)
        elif name == "spreadsheet":
            line(0.35, 0.48, 0.68, 0.48)
            line(0.35, 0.62, 0.68, 0.62)
            line(0.46, 0.42, 0.46, 0.72)
            line(0.58, 0.42, 0.58, 0.72)
    elif name == "folder":
        path = QPainterPath()
        path.moveTo(s * 0.18, s * 0.32)
        path.lineTo(s * 0.42, s * 0.32)
        path.lineTo(s * 0.51, s * 0.42)
        path.lineTo(s * 0.82, s * 0.42)
        path.lineTo(s * 0.76, s * 0.78)
        path.lineTo(s * 0.21, s * 0.78)
        path.closeSubpath()
        painter.drawPath(path)
    elif name == "image":
        painter.drawRoundedRect(QRectF(s * 0.18, s * 0.20, s * 0.64, s * 0.60), s * 0.07, s * 0.07)
        painter.drawEllipse(QRectF(s * 0.31, s * 0.31, s * 0.12, s * 0.12))
        path = QPainterPath()
        path.moveTo(s * 0.23, s * 0.70)
        path.lineTo(s * 0.42, s * 0.52)
        path.lineTo(s * 0.53, s * 0.62)
        path.lineTo(s * 0.64, s * 0.49)
        path.lineTo(s * 0.78, s * 0.68)
        painter.drawPath(path)
    elif name == "search":
        painter.drawEllipse(QRectF(s * 0.20, s * 0.20, s * 0.46, s * 0.46))
        line(0.60, 0.60, 0.80, 0.80)
    elif name == "check":
        line(0.22, 0.52, 0.42, 0.72)
        line(0.42, 0.72, 0.80, 0.30)
    elif name == "warning":
        path = QPainterPath()
        path.moveTo(s * 0.50, s * 0.14)
        path.lineTo(s * 0.86, s * 0.80)
        path.lineTo(s * 0.14, s * 0.80)
        path.closeSubpath()
        painter.drawPath(path)
        line(0.50, 0.36, 0.50, 0.58)
        painter.drawPoint(int(s * 0.50), int(s * 0.69))
    elif name == "info":
        painter.drawEllipse(QRectF(s * 0.18, s * 0.18, s * 0.64, s * 0.64))
        line(0.50, 0.44, 0.50, 0.68)
        painter.drawPoint(int(s * 0.50), int(s * 0.32))
    elif name == "edit":
        line(0.22, 0.72, 0.30, 0.50)
        line(0.30, 0.50, 0.66, 0.20)
        line(0.66, 0.20, 0.79, 0.33)
        line(0.79, 0.33, 0.43, 0.64)
        line(0.43, 0.64, 0.22, 0.72)
        line(0.22, 0.72, 0.20, 0.80)
    elif name == "eye":
        path = QPainterPath()
        path.moveTo(s * 0.12, s * 0.50)
        path.quadTo(s * 0.50, s * 0.16, s * 0.88, s * 0.50)
        path.quadTo(s * 0.50, s * 0.84, s * 0.12, s * 0.50)
        painter.drawPath(path)
        painter.drawEllipse(QRectF(s * 0.40, s * 0.40, s * 0.20, s * 0.20))
    elif name == "trash":
        painter.drawRoundedRect(QRectF(s * 0.29, s * 0.31, s * 0.42, s * 0.49), s * 0.03, s * 0.03)
        line(0.23, 0.27, 0.77, 0.27)
        line(0.41, 0.20, 0.59, 0.20)
        line(0.42, 0.42, 0.42, 0.68)
        line(0.58, 0.42, 0.58, 0.68)
    elif name == "plus":
        line(0.50, 0.22, 0.50, 0.78)
        line(0.22, 0.50, 0.78, 0.50)
    elif name == "export":
        painter.drawRoundedRect(QRectF(s * 0.18, s * 0.30, s * 0.46, s * 0.52), s * 0.04, s * 0.04)
        line(0.45, 0.50, 0.80, 0.50)
        line(0.80, 0.50, 0.66, 0.36)
        line(0.80, 0.50, 0.66, 0.64)
    elif name == "calendar":
        painter.drawRoundedRect(QRectF(s * 0.18, s * 0.24, s * 0.64, s * 0.60), s * 0.05, s * 0.05)
        line(0.18, 0.40, 0.82, 0.40)
        line(0.34, 0.16, 0.34, 0.31)
        line(0.66, 0.16, 0.66, 0.31)
    elif name == "clock":
        painter.drawEllipse(QRectF(s * 0.18, s * 0.18, s * 0.64, s * 0.64))
        line(0.50, 0.31, 0.50, 0.53)
        line(0.50, 0.53, 0.65, 0.62)
    elif name == "user":
        painter.drawEllipse(QRectF(s * 0.37, s * 0.19, s * 0.26, s * 0.26))
        path = QPainterPath()
        path.moveTo(s * 0.24, s * 0.80)
        path.quadTo(s * 0.28, s * 0.53, s * 0.50, s * 0.53)
        path.quadTo(s * 0.72, s * 0.53, s * 0.76, s * 0.80)
        painter.drawPath(path)
    elif name == "automation":
        painter.drawEllipse(QRectF(s * 0.19, s * 0.19, s * 0.23, s * 0.23))
        painter.drawEllipse(QRectF(s * 0.58, s * 0.58, s * 0.23, s * 0.23))
        line(0.39, 0.36, 0.64, 0.61)
        line(0.57, 0.61, 0.64, 0.61)
        line(0.64, 0.54, 0.64, 0.61)
    elif name == "refresh":
        path = QPainterPath()
        path.moveTo(s * 0.74, s * 0.34)
        path.quadTo(s * 0.50, s * 0.12, s * 0.27, s * 0.34)
        path.quadTo(s * 0.08, s * 0.53, s * 0.27, s * 0.72)
        painter.drawPath(path)
        line(0.68, 0.21, 0.75, 0.34)
        line(0.75, 0.34, 0.60, 0.35)
        path2 = QPainterPath()
        path2.moveTo(s * 0.26, s * 0.66)
        path2.quadTo(s * 0.50, s * 0.88, s * 0.73, s * 0.66)
        painter.drawPath(path2)
    elif name == "chevron-right":
        line(0.38, 0.25, 0.62, 0.50)
        line(0.62, 0.50, 0.38, 0.75)
    elif name == "chevron-left":
        line(0.62, 0.25, 0.38, 0.50)
        line(0.38, 0.50, 0.62, 0.75)
    elif name == "menu":
        line(0.22, 0.31, 0.78, 0.31)
        line(0.22, 0.50, 0.78, 0.50)
        line(0.22, 0.69, 0.78, 0.69)
    elif name == "minimize":
        line(0.28, 0.62, 0.72, 0.62)
    elif name == "maximize":
        painter.drawRect(QRectF(s * 0.28, s * 0.28, s * 0.44, s * 0.44))
    elif name == "restore":
        painter.drawRect(QRectF(s * 0.24, s * 0.36, s * 0.40, s * 0.40))
        line(0.36, 0.24, 0.76, 0.24)
        line(0.76, 0.24, 0.76, 0.64)
        line(0.64, 0.36, 0.76, 0.36)
    elif name == "close":
        line(0.32, 0.32, 0.68, 0.68)
        line(0.68, 0.32, 0.32, 0.68)
    else:
        painter.drawEllipse(QRectF(s * 0.32, s * 0.32, s * 0.36, s * 0.36))

    painter.end()
    return QIcon(pixmap)


class IconBadge(QFrame):
    """Ícone em cápsula usado por estados vazios, cards e banners."""

    def __init__(self, icon_name: str, kind: str = "accent", size: int = 42,
                 parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._icon_name = icon_name
        self._kind = kind
        self.setFixedSize(scaled(size), scaled(size))

    def paintEvent(self, event) -> None:  # noqa: N802
        super().paintEvent(event)
        color = {
            "accent": COLORS["accent"],
            "success": COLORS["success"],
            "warning": COLORS["warning"],
            "error": COLORS["error"],
            "neutral": COLORS["text_muted"],
        }.get(self._kind, COLORS["accent"])
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        rect = QRectF(1, 1, self.width() - 2, self.height() - 2)
        bg = QColor(color)
        bg.setAlpha(24)
        painter.setPen(QPen(QColor(COLORS["border_strong"]), 1))
        painter.setBrush(bg)
        painter.drawRoundedRect(rect, scaled(11), scaled(11))
        make_line_icon(self._icon_name, color, scaled(21)).paint(painter, self.rect(), Qt.AlignCenter)


# ---------------------------------------------------------------------------
# Surfaces / headers / metrics
# ---------------------------------------------------------------------------


class Card(QFrame):
    """Alias histórico para uma superfície de conteúdo."""

    def __init__(self, parent: QWidget | None = None, padding: int | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("SectionCard")
        pad = padding if padding is not None else scaled(SPACE["xl"])
        self._layout = QVBoxLayout(self)
        self._layout.setContentsMargins(pad, pad, pad, pad)
        self._layout.setSpacing(scaled(SPACE["md"]))

    def body(self) -> QVBoxLayout:
        return self._layout


class PageSurface(Card):
    """Compatibilidade com páginas antigas; equivalente a ``SectionCard``."""

    def __init__(self, parent: QWidget | None = None, padding: int | None = None) -> None:
        super().__init__(parent, padding)
        self.setObjectName("PageSurface")


class SectionCard(Card):
    def __init__(self, title: str = "", subtitle: str = "", parent: QWidget | None = None,
                 padding: int | None = None) -> None:
        super().__init__(parent, padding)
        self.setObjectName("SectionCard")
        if title:
            header = QVBoxLayout()
            header.setSpacing(scaled(2))
            title_label = QLabel(title)
            title_label.setObjectName("H2")
            header.addWidget(title_label)
            if subtitle:
                subtitle_label = QLabel(subtitle)
                subtitle_label.setObjectName("Subtle")
                subtitle_label.setWordWrap(True)
                header.addWidget(subtitle_label)
            self._layout.addLayout(header)


class PageHeader(QWidget):
    """Header padrão das páginas com título e slot de ações à direita."""

    def __init__(self, eyebrow: str, title: str, subtitle: str,
                 parent: QWidget | None = None) -> None:
        super().__init__(parent)
        row = QHBoxLayout(self)
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(scaled(SPACE["lg"]))

        text = QVBoxLayout()
        text.setSpacing(scaled(2))
        eyebrow_label = QLabel(eyebrow.upper())
        eyebrow_label.setObjectName("Eyebrow")
        title_label = QLabel(title)
        title_label.setObjectName("PageTitle")
        subtitle_label = QLabel(subtitle)
        subtitle_label.setObjectName("PageSubtitle")
        subtitle_label.setWordWrap(True)
        text.addWidget(eyebrow_label)
        text.addWidget(title_label)
        text.addWidget(subtitle_label)
        row.addLayout(text, 1)

        self.actions = QHBoxLayout()
        self.actions.setSpacing(scaled(SPACE["sm"]))
        row.addLayout(self.actions, 0)


class MetricPill(QLabel):
    """Métrica compacta para toolbar/header."""

    def __init__(self, text: str = "", kind: str = "neutral", parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setAlignment(Qt.AlignCenter)
        self.set_kind(kind)
        self.setText(text)

    def set_kind(self, kind: str) -> None:
        color = {
            "neutral": COLORS["text_muted"],
            "accent": COLORS["accent"],
            "warning": COLORS["warning"],
            "success": COLORS["success"],
            "error": COLORS["error"],
        }.get(kind, COLORS["text_muted"])
        self.setStyleSheet(
            f"color:{color}; background:{COLORS['bg_alt']}; border:1px solid {COLORS['border']};"
            f"border-radius:{RADIUS['pill']}px; padding:{scaled(4)}px {scaled(10)}px;"
            f"font-size:{scaled(10)}px; font-weight:800;"
        )


class MetricCard(QFrame):
    """Bloco de métrica grande para resumos de revisão/exportação."""

    def __init__(self, label: str, value: str = "-", hint: str = "",
                 kind: str = "neutral", parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("MetricCard")
        self.setMinimumWidth(scaled(120))
        layout = QVBoxLayout(self)
        layout.setContentsMargins(scaled(14), scaled(12), scaled(14), scaled(12))
        layout.setSpacing(scaled(2))
        self.value_label = QLabel(value)
        self.value_label.setObjectName("MetricValue")
        label_widget = QLabel(label)
        label_widget.setObjectName("MetricLabel")
        layout.addWidget(self.value_label)
        layout.addWidget(label_widget)
        if hint:
            hint_widget = QLabel(hint)
            hint_widget.setObjectName("MetricHint")
            hint_widget.setWordWrap(True)
            layout.addWidget(hint_widget)
        self.set_kind(kind)

    def set_value(self, value: str) -> None:
        self.value_label.setText(value)

    def set_kind(self, kind: str) -> None:
        color = {
            "neutral": COLORS["text"],
            "accent": COLORS["accent"],
            "success": COLORS["success"],
            "warning": COLORS["warning"],
            "error": COLORS["error"],
        }.get(kind, COLORS["text"])
        self.value_label.setStyleSheet(f"color:{color};")


class EmptyState(QFrame):
    """Estado vazio centralizado, com ícone e texto."""

    def __init__(self, title: str, hint: str, icon: str = "file",
                 parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("EmptyState")
        layout = QVBoxLayout(self)
        layout.setAlignment(Qt.AlignCenter)
        layout.setContentsMargins(scaled(SPACE["2xl"]), scaled(SPACE["2xl"]),
                                  scaled(SPACE["2xl"]), scaled(SPACE["2xl"]))
        layout.setSpacing(scaled(SPACE["sm"]))
        layout.addStretch(1)
        badge = IconBadge(icon, "neutral", 48)
        layout.addWidget(badge, 0, Qt.AlignHCenter)
        title_label = QLabel(title)
        title_label.setObjectName("H2")
        title_label.setAlignment(Qt.AlignCenter)
        hint_label = QLabel(hint)
        hint_label.setObjectName("Subtle")
        hint_label.setAlignment(Qt.AlignCenter)
        hint_label.setWordWrap(True)
        hint_label.setMaximumWidth(scaled(460))
        layout.addWidget(title_label)
        layout.addWidget(hint_label)
        layout.addStretch(1)


class StateBanner(QFrame):
    """Banner semântico para pronto/atenção/erro/info."""

    def __init__(self, title: str = "", message: str = "", kind: str = "info",
                 icon: str | None = None, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._title = QLabel()
        self._title.setObjectName("H3")
        self._message = QLabel()
        self._message.setObjectName("Subtle")
        self._message.setWordWrap(True)
        self._icon = IconBadge(icon or "info", kind if kind in {"success", "warning", "error"} else "accent", 36)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(scaled(12), scaled(10), scaled(14), scaled(10))
        layout.setSpacing(scaled(10))
        layout.addWidget(self._icon, 0, Qt.AlignTop)
        text = QVBoxLayout()
        text.setSpacing(scaled(2))
        text.addWidget(self._title)
        text.addWidget(self._message)
        layout.addLayout(text, 1)
        self.set_state(title, message, kind, icon)

    def set_state(self, title: str, message: str, kind: str = "info", icon: str | None = None) -> None:
        color = {
            "success": COLORS["success"],
            "warning": COLORS["warning"],
            "error": COLORS["error"],
            "info": COLORS["accent"],
        }.get(kind, COLORS["accent"])
        soft = {
            "success": COLORS["success_soft"],
            "warning": COLORS["warning_soft"],
            "error": COLORS["error_soft"],
            "info": COLORS["accent_soft"],
        }.get(kind, COLORS["accent_soft"])
        self._title.setText(title)
        self._message.setText(message)
        self._title.setStyleSheet(f"color:{color};")
        self.setStyleSheet(
            f"StateBanner {{ background:{soft}; border:1px solid {color};"
            f"border-radius:{RADIUS['md']}px; }}"
        )
        if icon:
            self._icon._icon_name = icon
            self._icon._kind = kind if kind in {"success", "warning", "error"} else "accent"
            self._icon.update()


class DetailRow(QWidget):
    """Par label/valor usado em inspectors e resumos."""

    def __init__(self, label: str, value: str = "-", parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scaled(SPACE["sm"]))
        label_widget = QLabel(label)
        label_widget.setObjectName("Dim")
        label_widget.setMinimumWidth(scaled(88))
        self.value_label = QLabel(value)
        self.value_label.setObjectName("Body")
        self.value_label.setTextInteractionFlags(Qt.TextSelectableByMouse)
        self.value_label.setWordWrap(True)
        layout.addWidget(label_widget, 0, Qt.AlignTop)
        layout.addWidget(self.value_label, 1, Qt.AlignTop)

    def set_value(self, value: str) -> None:
        self.value_label.setText(value or "-")


class ShortcutHint(QLabel):
    def __init__(self, text: str, parent: QWidget | None = None) -> None:
        super().__init__(text, parent)
        self.setObjectName("Dim")
        self.setStyleSheet(
            f"background:{COLORS['bg_alt']}; border:1px solid {COLORS['border']};"
            f"border-radius:{RADIUS['xs']}px; padding:{scaled(2)}px {scaled(6)}px;"
        )


# ---------------------------------------------------------------------------
# Clickable action cards / drop zone
# ---------------------------------------------------------------------------


class ActionCard(QFrame):
    clicked = Signal()

    def __init__(self, icon: str, title: str, subtitle: str, action_text: str = "Abrir",
                 parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("ActionCard")
        self.setCursor(Qt.PointingHandCursor)
        self.setFocusPolicy(Qt.StrongFocus)
        self.setAccessibleName(title)
        self.setAccessibleDescription(subtitle)
        layout = QHBoxLayout(self)
        layout.setContentsMargins(scaled(12), scaled(11), scaled(12), scaled(11))
        layout.setSpacing(scaled(10))
        layout.addWidget(IconBadge(icon, "accent", 38), 0, Qt.AlignTop)
        text = QVBoxLayout()
        text.setSpacing(scaled(2))
        title_label = QLabel(title)
        title_label.setObjectName("H3")
        subtitle_label = QLabel(subtitle)
        subtitle_label.setObjectName("Dim")
        subtitle_label.setWordWrap(True)
        text.addWidget(title_label)
        text.addWidget(subtitle_label)
        layout.addLayout(text, 1)
        action = QLabel(action_text)
        action.setStyleSheet(f"color:{COLORS['accent']}; font-weight:800;")
        layout.addWidget(action, 0, Qt.AlignVCenter)

    def mouseReleaseEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.LeftButton and self.rect().contains(event.position().toPoint()):
            self.clicked.emit()
            event.accept()
            return
        super().mouseReleaseEvent(event)

    def keyPressEvent(self, event) -> None:  # noqa: N802
        if event.key() in (Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space):
            self.clicked.emit()
            event.accept()
            return
        super().keyPressEvent(event)


class DropZone(QFrame):
    """Área de drag&drop com affordance visual forte e suporte a clique."""

    files_dropped = Signal(list)
    clicked = Signal()

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setAcceptDrops(True)
        self.setCursor(Qt.PointingHandCursor)
        self.setFocusPolicy(Qt.StrongFocus)
        self.setAccessibleName("Adicionar prints")
        self.setAccessibleDescription("Solte imagens ou pastas aqui, ou pressione Enter para selecionar arquivos.")
        self._hover = False
        self._enabled_for_input = True
        self._apply_style()

        layout = QVBoxLayout(self)
        layout.setAlignment(Qt.AlignCenter)
        layout.setContentsMargins(scaled(SPACE["xl"]), scaled(SPACE["xl"]),
                                  scaled(SPACE["xl"]), scaled(SPACE["xl"]))
        layout.setSpacing(scaled(SPACE["sm"]))
        self.icon_badge = IconBadge("upload", "accent", 52)
        title = QLabel("Solte seus prints aqui")
        title.setObjectName("H1")
        title.setAlignment(Qt.AlignCenter)
        hint = QLabel("ou clique para selecionar imagens · PNG, JPG, WEBP, BMP e TIFF")
        hint.setObjectName("Subtle")
        hint.setAlignment(Qt.AlignCenter)
        hint.setWordWrap(True)
        layout.addWidget(self.icon_badge, 0, Qt.AlignHCenter)
        layout.addWidget(title)
        layout.addWidget(hint)

    def set_input_enabled(self, enabled: bool) -> None:
        self._enabled_for_input = enabled
        self.setAcceptDrops(enabled)
        self.setCursor(Qt.PointingHandCursor if enabled else Qt.ForbiddenCursor)
        self._apply_style()

    def _apply_style(self) -> None:
        border = COLORS["accent"] if self._hover else COLORS["border_strong"]
        bg = COLORS["accent_soft"] if self._hover else COLORS["bg_alt"]
        if not self._enabled_for_input:
            bg = COLORS["surface"]
            border = COLORS["border"]
        self.setStyleSheet(
            f"DropZone {{ background:{bg}; border:1px dashed {border};"
            f"border-radius:{RADIUS['lg']}px; }}"
        )

    def mouseReleaseEvent(self, event) -> None:  # noqa: N802
        if self._enabled_for_input and event.button() == Qt.LeftButton:
            self.clicked.emit()
            event.accept()
            return
        super().mouseReleaseEvent(event)

    def keyPressEvent(self, event) -> None:  # noqa: N802
        if self._enabled_for_input and event.key() in (Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space):
            self.clicked.emit()
            event.accept()
            return
        super().keyPressEvent(event)

    def dragEnterEvent(self, event) -> None:  # noqa: N802
        if self._enabled_for_input and event.mimeData().hasUrls():
            event.acceptProposedAction()
            self._hover = True
            self._apply_style()

    def dragLeaveEvent(self, event) -> None:  # noqa: N802
        self._hover = False
        self._apply_style()

    def dropEvent(self, event) -> None:  # noqa: N802
        self._hover = False
        self._apply_style()
        if not self._enabled_for_input:
            return
        paths: list[Path] = []
        for url in event.mimeData().urls():
            if not url.isLocalFile():
                continue
            path = Path(url.toLocalFile())
            if path.is_dir() or (path.is_file() and is_supported_image(path)):
                paths.append(path)
        if paths:
            self.files_dropped.emit(paths)
            event.acceptProposedAction()


# ---------------------------------------------------------------------------
# Navigation rail
# ---------------------------------------------------------------------------


class _NavItem(QPushButton):
    def __init__(self, icon_name: str, title: str, subtitle: str, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("NavItem")
        self.setCheckable(True)
        self.setAutoExclusive(True)
        self._icon_name = icon_name
        self._title = title
        self._subtitle = subtitle
        self._compact = False
        self.setIconSize(QSize(scaled(18), scaled(18)))
        self.setToolTip(f"{title} — {subtitle}")
        self.setAccessibleName(title)
        self.setAccessibleDescription(subtitle)
        self.toggled.connect(self._refresh_icon)
        self._refresh_text()
        self._refresh_icon()

    def set_compact(self, compact: bool) -> None:
        self._compact = compact
        self._refresh_text()

    def _refresh_text(self) -> None:
        self.setText("" if self._compact else f"  {self._title}")

    def _refresh_icon(self, *_args) -> None:
        color = COLORS["accent"] if self.isChecked() else COLORS["text_muted"]
        self.setIcon(make_line_icon(self._icon_name, color, scaled(18)))


class NavigationRail(QFrame):
    """Navegação persistente do fluxo + resumo em tempo real da sessão."""

    step_clicked = Signal(int)
    new_session_requested = Signal()

    def __init__(self, steps: list[tuple[str, str, str]], parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("NavigationRail")
        self._compact = False
        self._ocr_ok: bool | None = None
        self._ocr_text = "OCR"
        self._ocr_tooltip = ""
        self._items: list[_NavItem] = []
        self.setFixedWidth(scaled(228))

        root = QVBoxLayout(self)
        root.setContentsMargins(scaled(12), scaled(16), scaled(12), scaled(14))
        root.setSpacing(scaled(8))

        self.flow_label = QLabel("FLUXO DO MÊS")
        self.flow_label.setObjectName("RailEyebrow")
        root.addWidget(self.flow_label)

        for index, (icon, title, subtitle) in enumerate(steps):
            item = _NavItem(icon, title, subtitle)
            item.clicked.connect(lambda _checked=False, i=index: self.step_clicked.emit(i))
            self._items.append(item)
            root.addWidget(item)

        root.addSpacing(scaled(8))
        self.summary = QFrame()
        self.summary.setObjectName("RailSummary")
        summary_layout = QVBoxLayout(self.summary)
        summary_layout.setContentsMargins(scaled(12), scaled(12), scaled(12), scaled(12))
        summary_layout.setSpacing(scaled(8))
        self.summary_title = QLabel("SESSÃO")
        self.summary_title.setObjectName("RailEyebrow")
        summary_layout.addWidget(self.summary_title)

        self._summary_rows: dict[str, tuple[QLabel, QLabel]] = {}
        for key, label in (
            ("prints", "Prints"),
            ("records", "Registros"),
            ("issues", "Pendências"),
            ("hours", "Total"),
        ):
            row = QHBoxLayout()
            row.setSpacing(scaled(6))
            name = QLabel(label)
            name.setObjectName("RailMetricLabel")
            value = QLabel("0")
            value.setObjectName("RailMetricValue")
            value.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
            row.addWidget(name)
            row.addStretch(1)
            row.addWidget(value)
            summary_layout.addLayout(row)
            self._summary_rows[key] = (name, value)
        root.addWidget(self.summary)
        root.addStretch(1)

        self.ocr_status = StatusPill()
        root.addWidget(self.ocr_status)
        self.new_month = QPushButton("Novo mês")
        self.new_month.setObjectName("Ghost")
        self.new_month.setIcon(make_line_icon("refresh"))
        self.new_month.setToolTip("Começar uma sessão limpa · Ctrl+N")
        self.new_month.setAccessibleName("Começar novo mês")
        self.new_month.clicked.connect(self.new_session_requested.emit)
        root.addWidget(self.new_month)

        self.set_current(0)

    def set_current(self, index: int) -> None:
        if 0 <= index < len(self._items):
            self._items[index].setChecked(True)

    def set_summary(self, *, prints: int, records: int, issues: int, hours: str) -> None:
        values = {
            "prints": str(prints),
            "records": str(records),
            "issues": str(issues),
            "hours": hours,
        }
        for key, value in values.items():
            self._summary_rows[key][1].setText(value)
        issue_value = self._summary_rows["issues"][1]
        issue_value.setStyleSheet(
            f"color:{COLORS['warning'] if issues else COLORS['success']}; font-weight:800;"
        )

    def set_ocr_state(self, ok: bool | None, text: str, tooltip: str = "") -> None:
        self._ocr_ok = ok
        self._ocr_text = text
        self._ocr_tooltip = tooltip
        self.ocr_status.set_state(ok, "OCR" if self._compact else text)
        self.ocr_status.setToolTip(tooltip)

    def set_compact(self, compact: bool) -> None:
        if self._compact == compact:
            return
        self._compact = compact
        self.setFixedWidth(scaled(72 if compact else 228))
        self.flow_label.setVisible(not compact)
        self.summary.setVisible(not compact)
        for item in self._items:
            item.set_compact(compact)
        self.ocr_status.setVisible(True)
        self.ocr_status.set_state(self._ocr_ok, "OCR" if compact else self._ocr_text)
        self.ocr_status.setToolTip(self._ocr_tooltip)
        self.new_month.setText("" if compact else "Novo mês")
        self.new_month.setToolTip("Novo mês · Ctrl+N")


# ---------------------------------------------------------------------------
# Status / chips / stepper legado
# ---------------------------------------------------------------------------


class StatusPill(QLabel):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setAlignment(Qt.AlignCenter)
        self.set_state(None, "Verificando OCR")

    def set_state(self, ok: bool | None, text: str) -> None:
        if ok is None:
            color, bg = COLORS["text_muted"], COLORS["surface_2"]
        elif ok:
            color, bg = COLORS["success"], COLORS["success_soft"]
        else:
            color, bg = COLORS["error"], COLORS["error_soft"]
        self.setText(text)
        self.setStyleSheet(
            f"color:{color}; background:{bg}; border:1px solid {COLORS['border']};"
            f"border-radius:{RADIUS['pill']}px; padding:{scaled(5)}px {scaled(9)}px;"
            f"font-size:{scaled(10)}px; font-weight:800;"
        )


_CHIP_COLORS = {
    "ok": (COLORS["success"], COLORS["success_soft"]),
    "revisar": (COLORS["warning"], COLORS["warning_soft"]),
    "editado": (COLORS["accent"], COLORS["accent_soft"]),
    "ignorado": (COLORS["text_dim"], "rgba(113, 128, 148, 0.12)"),
    "erro": (COLORS["error"], COLORS["error_soft"]),
}
_CHIP_LABEL = {
    "ok": "OK",
    "revisar": "Revisar",
    "editado": "Editado",
    "ignorado": "Ignorado",
    "erro": "Erro",
}


def chip_style_for(status: str) -> tuple[str, str]:
    return _CHIP_COLORS.get(status, _CHIP_COLORS["erro"])


def chip_label_for(status: str) -> str:
    return _CHIP_LABEL.get(status, status)


class StatusChip(QLabel):
    def __init__(self, status: str = "ok", parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setAlignment(Qt.AlignCenter)
        self.set_status(status)

    def set_status(self, status: str) -> None:
        color, bg = chip_style_for(status)
        self.setText(chip_label_for(status))
        self.setStyleSheet(
            f"color:{color}; background:{bg}; border:1px solid {color};"
            f"border-radius:{RADIUS['pill']}px; padding:{scaled(3)}px {scaled(9)}px;"
            f"font-size:{scaled(10)}px; font-weight:800;"
        )


class StepHeader(QFrame):
    """Stepper horizontal legado; mantido para compatibilidade externa."""

    step_clicked = Signal(int)

    def __init__(self, steps: list[tuple[str, str]], parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        self._buttons: list[QPushButton] = []
        for index, (title, _subtitle) in enumerate(steps):
            button = QPushButton(title)
            button.setObjectName("FilterChip")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, i=index: self.step_clicked.emit(i))
            self._buttons.append(button)
            layout.addWidget(button)
        self.set_current(0)

    def set_current(self, index: int) -> None:
        for i, button in enumerate(self._buttons):
            button.setChecked(i == index)


# ---------------------------------------------------------------------------
# Toasts
# ---------------------------------------------------------------------------


class Toast(QFrame):
    """Notificação não-bloqueante com empilhamento automático."""

    def __init__(self, parent: QWidget, text: str, kind: str = "info", timeout: int = 3600) -> None:
        super().__init__(parent)
        self.setAttribute(Qt.WA_DeleteOnClose, True)
        self._kind = kind
        accent = {
            "success": COLORS["success"],
            "error": COLORS["error"],
            "warning": COLORS["warning"],
            "info": COLORS["accent"],
        }.get(kind, COLORS["accent"])
        self.setMaximumWidth(scaled(440))
        self.setMinimumWidth(scaled(280))
        self.setStyleSheet(
            f"Toast {{ background:{COLORS['surface_2']}; border:1px solid {COLORS['border_strong']};"
            f"border-left:{scaled(4)}px solid {accent}; border-radius:{RADIUS['md']}px; }}"
        )
        layout = QHBoxLayout(self)
        layout.setContentsMargins(scaled(14), scaled(11), scaled(12), scaled(11))
        layout.setSpacing(scaled(9))
        icon = QLabel()
        icon.setPixmap(make_line_icon(
            "check" if kind == "success" else "warning" if kind in {"warning", "error"} else "info",
            accent,
            scaled(18),
        ).pixmap(scaled(18), scaled(18)))
        layout.addWidget(icon, 0, Qt.AlignTop)
        label = QLabel(text)
        label.setWordWrap(True)
        label.setObjectName("Body")
        layout.addWidget(label, 1)
        self._timeout = timeout

    def show_toast(self) -> None:
        parent = self.parentWidget()
        if parent is None:
            self.show()
            return
        self.adjustSize()
        margin = scaled(20)
        gap = scaled(8)
        siblings = [
            child for child in parent.children()
            if isinstance(child, Toast) and child is not self and child.isVisible()
        ]
        stack_height = sum(child.height() + gap for child in siblings)
        x = max(margin, parent.width() - self.width() - margin)
        y = max(margin, parent.height() - self.height() - margin - stack_height)
        self.move(x, y + scaled(12))
        self.show()
        self.raise_()

        effect = QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(effect)
        fade = QPropertyAnimation(effect, b"opacity", self)
        fade.setDuration(150)
        fade.setStartValue(0.0)
        fade.setEndValue(1.0)
        fade.setEasingCurve(QEasingCurve.OutCubic)
        fade.start()
        self._fade = fade

        slide = QPropertyAnimation(self, b"pos", self)
        slide.setDuration(180)
        slide.setStartValue(QPoint(x, y + scaled(12)))
        slide.setEndValue(QPoint(x, y))
        slide.setEasingCurve(QEasingCurve.OutCubic)
        slide.start()
        self._slide = slide
        QTimer.singleShot(self._timeout, self.close)
