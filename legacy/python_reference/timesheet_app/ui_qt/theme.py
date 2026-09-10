"""Design system visual do OktaPonto.

O módulo concentra paleta, tipografia, espaçamento, raios, escala de DPI e o QSS
completo da aplicação. As páginas devem preferir ``objectName``/propriedades Qt
a estilos inline; isso mantém a interface coerente e reduz regressões visuais.
"""

from __future__ import annotations

from PySide6.QtGui import QColor, QFont, QPalette
from PySide6.QtWidgets import QApplication


# ---------------------------------------------------------------------------
# Design tokens (baseline: 96 DPI)
# ---------------------------------------------------------------------------

COLORS = {
    "bg": "#0B0E13",
    "bg_alt": "#0F141C",
    "sidebar": "#0E1219",
    "surface": "#141A23",
    "surface_2": "#1A2230",
    "surface_3": "#222D3C",
    "surface_hover": "#202A38",
    "border": "#263140",
    "border_strong": "#354256",
    "text": "#F2F5FA",
    "text_muted": "#AAB4C3",
    "text_dim": "#718094",
    "accent": "#6C8CFF",
    "accent_hover": "#83A0FF",
    "accent_press": "#5677E8",
    "accent_soft": "rgba(108, 140, 255, 0.13)",
    "success": "#43D39A",
    "success_soft": "rgba(67, 211, 154, 0.13)",
    "warning": "#F2B84B",
    "warning_soft": "rgba(242, 184, 75, 0.13)",
    "error": "#FF6F7A",
    "error_soft": "rgba(255, 111, 122, 0.13)",
    "info": "#69B7FF",
    "info_soft": "rgba(105, 183, 255, 0.13)",
    "on_accent": "#08101E",
    "white": "#FFFFFF",
}

RADIUS = {
    "xs": 5,
    "sm": 8,
    "md": 12,
    "lg": 16,
    "xl": 20,
    "pill": 999,
}

SPACE = {
    "2xs": 2,
    "xs": 4,
    "sm": 8,
    "md": 12,
    "lg": 16,
    "xl": 24,
    "2xl": 32,
}

FONT_FAMILY = "system-ui"

_SCALE: float = 1.0


def get_scale() -> float:
    """Retorna o fator de escala derivado do DPI lógico da tela principal."""
    return _SCALE


def scaled(value: int | float) -> int:
    """Converte logical-px do design system para o DPI atual."""
    return max(1, round(value * _SCALE))


def apply_dark_theme(app: QApplication) -> None:
    """Aplica o tema OktaPonto; nome legado mantido por compatibilidade."""
    global _SCALE
    screen = app.primaryScreen()
    if screen:
        dpi = screen.logicalDotsPerInch()
        _SCALE = max(0.85, min(1.60, dpi / 96.0))

    app.setStyle("Fusion")
    font = QFont(app.font())
    font.setPointSize(max(9, round(10 * _SCALE)))
    app.setFont(font)
    app.setPalette(_palette())
    app.setStyleSheet(build_stylesheet(_SCALE))


def _palette() -> QPalette:
    c = COLORS
    palette = QPalette()
    palette.setColor(QPalette.Window, QColor(c["bg"]))
    palette.setColor(QPalette.WindowText, QColor(c["text"]))
    palette.setColor(QPalette.Base, QColor(c["bg_alt"]))
    palette.setColor(QPalette.AlternateBase, QColor(c["surface"]))
    palette.setColor(QPalette.Text, QColor(c["text"]))
    palette.setColor(QPalette.Button, QColor(c["surface_2"]))
    palette.setColor(QPalette.ButtonText, QColor(c["text"]))
    palette.setColor(QPalette.ToolTipBase, QColor(c["surface_2"]))
    palette.setColor(QPalette.ToolTipText, QColor(c["text"]))
    palette.setColor(QPalette.Highlight, QColor(c["accent"]))
    palette.setColor(QPalette.HighlightedText, QColor(c["on_accent"]))
    palette.setColor(QPalette.Link, QColor(c["accent"]))
    palette.setColor(QPalette.PlaceholderText, QColor(c["text_dim"]))
    palette.setColor(QPalette.Disabled, QPalette.Text, QColor(c["text_dim"]))
    palette.setColor(QPalette.Disabled, QPalette.ButtonText, QColor(c["text_dim"]))
    palette.setColor(QPalette.Disabled, QPalette.WindowText, QColor(c["text_dim"]))
    return palette


def build_stylesheet(scale: float = 1.0) -> str:
    """Constrói o QSS global usando apenas os tokens do design system."""
    def sp(value: int | float) -> int:
        return max(1, round(value * scale))

    c = COLORS
    r = RADIUS

    return f"""
    * {{
        outline: none;
    }}
    QWidget {{
        color: {c['text']};
        font-size: {sp(13)}px;
    }}
    QMainWindow, QDialog {{ background: {c['bg']}; }}
    QWidget#AppShell {{ background: {c['bg']}; }}
    QStackedWidget#ContentStack {{ background: {c['bg']}; }}

    /* Window chrome ------------------------------------------------------ */
    QWidget#TitleBar {{
        background: {c['bg']};
        border-bottom: 1px solid {c['border']};
    }}
    QLabel#BrandMark {{
        background: {c['accent']};
        color: {c['on_accent']};
        border-radius: {sp(7)}px;
        font-size: {sp(11)}px;
        font-weight: 900;
    }}
    QLabel#TitleBarText {{
        color: {c['text']};
        font-size: {sp(12)}px;
        font-weight: 750;
    }}
    QLabel#TitleBarContext {{
        color: {c['text_dim']};
        font-size: {sp(11)}px;
    }}
    QPushButton#TitleBarBtn, QPushButton#TitleBarBtnClose {{
        background: transparent;
        border: 1px solid transparent;
        padding: 0;
        min-height: {sp(30)}px;
        border-radius: {r['sm']}px;
    }}
    QPushButton#TitleBarBtn:hover {{
        background: {c['surface_2']};
        border-color: {c['border']};
    }}
    QPushButton#TitleBarBtn:focus {{ border-color: {c['accent']}; }}
    QPushButton#TitleBarBtnClose:hover {{
        background: {c['error']};
        border-color: {c['error']};
    }}

    /* Navigation rail --------------------------------------------------- */
    QFrame#NavigationRail {{
        background: {c['sidebar']};
        border-right: 1px solid {c['border']};
    }}
    QLabel#RailEyebrow {{
        color: {c['text_dim']};
        font-size: {sp(10)}px;
        font-weight: 800;
        letter-spacing: {sp(1)}px;
    }}
    QPushButton#NavItem {{
        background: transparent;
        color: {c['text_muted']};
        border: 1px solid transparent;
        border-radius: {r['md']}px;
        padding: {sp(10)}px {sp(12)}px;
        min-height: {sp(46)}px;
        text-align: left;
        font-size: {sp(13)}px;
        font-weight: 650;
    }}
    QPushButton#NavItem:hover {{
        background: {c['surface']};
        color: {c['text']};
    }}
    QPushButton#NavItem:checked {{
        background: {c['accent_soft']};
        border-color: rgba(108, 140, 255, 0.26);
        color: {c['text']};
    }}
    QPushButton#NavItem:focus {{ border-color: {c['accent']}; }}
    QFrame#RailSummary {{
        background: {c['surface']};
        border: 1px solid {c['border']};
        border-radius: {r['md']}px;
    }}
    QLabel#RailMetricValue {{
        color: {c['text']};
        font-size: {sp(13)}px;
        font-weight: 800;
    }}
    QLabel#RailMetricLabel {{
        color: {c['text_dim']};
        font-size: {sp(10)}px;
    }}

    /* Page headers / typography ----------------------------------------- */
    QLabel#Eyebrow {{
        color: {c['accent']};
        font-size: {sp(10)}px;
        font-weight: 850;
        letter-spacing: {sp(1)}px;
    }}
    QLabel#PageTitle {{
        color: {c['text']};
        font-size: {sp(22)}px;
        font-weight: 850;
    }}
    QLabel#PageSubtitle {{
        color: {c['text_muted']};
        font-size: {sp(12)}px;
    }}
    QLabel#H1 {{ color: {c['text']}; font-size: {sp(18)}px; font-weight: 800; }}
    QLabel#H2 {{ color: {c['text']}; font-size: {sp(14)}px; font-weight: 750; }}
    QLabel#H3 {{ color: {c['text']}; font-size: {sp(12)}px; font-weight: 750; }}
    QLabel#Body {{ color: {c['text_muted']}; font-size: {sp(12)}px; }}
    QLabel#Subtle {{ color: {c['text_muted']}; font-size: {sp(11)}px; }}
    QLabel#Dim {{ color: {c['text_dim']}; font-size: {sp(11)}px; }}
    QLabel#Mono {{ color: {c['text_muted']}; font-family: Consolas; font-size: {sp(11)}px; }}
    QLabel#MetricValue {{ color: {c['text']}; font-size: {sp(24)}px; font-weight: 850; }}
    QLabel#MetricLabel {{ color: {c['text_dim']}; font-size: {sp(10)}px; font-weight: 700; }}
    QLabel#MetricHint {{ color: {c['text_muted']}; font-size: {sp(10)}px; }}

    /* Surfaces ----------------------------------------------------------- */
    QFrame#PageSurface, QFrame#SectionCard {{
        background: {c['surface']};
        border: 1px solid {c['border']};
        border-radius: {r['lg']}px;
    }}
    QFrame#SectionCardElevated {{
        background: {c['surface_2']};
        border: 1px solid {c['border_strong']};
        border-radius: {r['lg']}px;
    }}
    QFrame#MetricCard {{
        background: {c['surface']};
        border: 1px solid {c['border']};
        border-radius: {r['md']}px;
    }}
    QFrame#EmptyState {{
        background: {c['bg_alt']};
        border: 1px dashed {c['border_strong']};
        border-radius: {r['lg']}px;
    }}
    QFrame#Inspector {{
        background: {c['surface']};
        border: 1px solid {c['border']};
        border-radius: {r['lg']}px;
    }}
    QFrame#Separator {{ background: {c['border']}; border: none; }}
    QFrame#ActionCard {{
        background: {c['bg_alt']};
        border: 1px solid {c['border']};
        border-radius: {r['md']}px;
    }}
    QFrame#ActionCard:hover {{
        background: {c['surface_2']};
        border-color: {c['border_strong']};
    }}

    /* Buttons ------------------------------------------------------------ */
    QPushButton {{
        background: {c['surface_2']};
        color: {c['text']};
        border: 1px solid {c['border']};
        border-radius: {r['sm']}px;
        padding: {sp(7)}px {sp(14)}px;
        min-height: {sp(34)}px;
        font-size: {sp(12)}px;
        font-weight: 700;
    }}
    QPushButton:hover {{ background: {c['surface_hover']}; border-color: {c['border_strong']}; }}
    QPushButton:pressed {{ background: {c['surface']}; }}
    QPushButton:focus {{ border-color: {c['accent']}; }}
    QPushButton:disabled {{
        background: {c['bg_alt']};
        border-color: {c['border']};
        color: {c['text_dim']};
    }}
    QPushButton#Accent {{
        background: {c['accent']};
        color: {c['on_accent']};
        border-color: {c['accent']};
        padding: {sp(8)}px {sp(18)}px;
        min-height: {sp(38)}px;
        font-weight: 800;
    }}
    QPushButton#Accent:hover {{ background: {c['accent_hover']}; border-color: {c['accent_hover']}; }}
    QPushButton#Accent:pressed {{ background: {c['accent_press']}; border-color: {c['accent_press']}; }}
    QPushButton#Accent:disabled {{ background: {c['surface_2']}; border-color: {c['border']}; color: {c['text_dim']}; }}
    QPushButton#Ghost {{
        background: transparent;
        border-color: transparent;
        color: {c['text_muted']};
    }}
    QPushButton#Ghost:hover {{ background: {c['surface_2']}; color: {c['text']}; }}
    QPushButton#Danger {{ background: transparent; color: {c['text_muted']}; border-color: {c['border']}; }}
    QPushButton#Danger:hover {{ background: {c['error_soft']}; color: {c['error']}; border-color: {c['error']}; }}
    QPushButton#ToolbarButton {{
        background: transparent;
        color: {c['text_muted']};
        border: 1px solid {c['border']};
        border-radius: {r['sm']}px;
        min-height: {sp(32)}px;
        padding: {sp(6)}px {sp(10)}px;
    }}
    QPushButton#ToolbarButton:hover {{ background: {c['surface_2']}; color: {c['text']}; border-color: {c['border_strong']}; }}
    QPushButton#IconButton {{
        background: transparent;
        border: 1px solid transparent;
        padding: 0;
        border-radius: {r['sm']}px;
    }}
    QPushButton#IconButton:hover {{ background: {c['surface_2']}; border-color: {c['border']}; }}
    QPushButton#FilterChip {{
        background: transparent;
        color: {c['text_muted']};
        border: 1px solid {c['border']};
        border-radius: {r['pill']}px;
        padding: {sp(5)}px {sp(11)}px;
        min-height: {sp(28)}px;
        font-size: {sp(11)}px;
        font-weight: 700;
    }}
    QPushButton#FilterChip:hover {{ background: {c['surface_2']}; color: {c['text']}; }}
    QPushButton#FilterChip:checked {{ background: {c['accent_soft']}; color: {c['accent']}; border-color: rgba(108, 140, 255, 0.46); }}

    /* Inputs ------------------------------------------------------------- */
    QLineEdit, QPlainTextEdit, QTextEdit, QComboBox, QSpinBox {{
        background: {c['bg_alt']};
        color: {c['text']};
        border: 1px solid {c['border']};
        border-radius: {r['sm']}px;
        padding: {sp(7)}px {sp(10)}px;
        min-height: {sp(32)}px;
        font-size: {sp(12)}px;
        selection-background-color: {c['accent']};
        selection-color: {c['on_accent']};
    }}
    QPlainTextEdit, QTextEdit {{ min-height: {sp(82)}px; }}
    QLineEdit:hover, QPlainTextEdit:hover, QTextEdit:hover, QComboBox:hover {{ border-color: {c['border_strong']}; }}
    QLineEdit:focus, QPlainTextEdit:focus, QTextEdit:focus, QComboBox:focus, QSpinBox:focus {{ border-color: {c['accent']}; }}
    QLineEdit:read-only {{ background: {c['surface']}; color: {c['text_muted']}; }}
    QComboBox::drop-down {{ border: none; width: {sp(26)}px; }}
    QComboBox QAbstractItemView {{
        background: {c['surface_2']};
        color: {c['text']};
        border: 1px solid {c['border_strong']};
        selection-background-color: {c['accent']};
        selection-color: {c['on_accent']};
        padding: {sp(4)}px;
    }}

    /* Checkboxes --------------------------------------------------------- */
    QCheckBox {{ spacing: {sp(9)}px; color: {c['text_muted']}; }}
    QCheckBox:hover {{ color: {c['text']}; }}
    QCheckBox::indicator {{
        width: {sp(17)}px;
        height: {sp(17)}px;
        border: 1px solid {c['border_strong']};
        border-radius: {sp(5)}px;
        background: {c['bg_alt']};
    }}
    QCheckBox::indicator:checked {{ background: {c['accent']}; border-color: {c['accent']}; }}
    QCheckBox::indicator:disabled {{ background: {c['surface']}; border-color: {c['border']}; }}

    /* Lists / tables ----------------------------------------------------- */
    QListWidget {{
        background: {c['bg_alt']};
        border: 1px solid {c['border']};
        border-radius: {r['md']}px;
        padding: {sp(4)}px;
    }}
    QListWidget::item {{
        border-radius: {r['sm']}px;
        padding: {sp(7)}px;
        margin: {sp(2)}px;
    }}
    QListWidget::item:hover {{ background: {c['surface']}; }}
    QListWidget::item:selected {{ background: {c['accent_soft']}; color: {c['text']}; }}

    QTableView#RecordsTable {{
        background: {c['bg_alt']};
        alternate-background-color: {c['surface']};
        border: 1px solid {c['border']};
        border-radius: {r['md']}px;
        gridline-color: transparent;
        selection-background-color: rgba(108, 140, 255, 0.18);
        selection-color: {c['text']};
        font-size: {sp(12)}px;
    }}
    QTableView#RecordsTable::item {{
        padding: {sp(8)}px {sp(8)}px;
        border-bottom: 1px solid rgba(53, 66, 86, 0.45);
    }}
    QTableView#RecordsTable::item:hover {{ background: rgba(255, 255, 255, 0.025); }}
    QTableView#RecordsTable QHeaderView::section {{
        background: {c['surface_2']};
        color: {c['text_muted']};
        border: none;
        border-bottom: 1px solid {c['border_strong']};
        padding: {sp(9)}px {sp(7)}px;
        font-weight: 800;
        font-size: {sp(10)}px;
    }}
    QTableCornerButton::section {{ background: {c['surface_2']}; border: none; }}

    /* Progress ----------------------------------------------------------- */
    QProgressBar {{
        background: {c['bg_alt']};
        border: 1px solid {c['border']};
        border-radius: {r['pill']}px;
        min-height: {sp(8)}px;
        max-height: {sp(8)}px;
        color: transparent;
    }}
    QProgressBar::chunk {{ background: {c['accent']}; border-radius: {r['pill']}px; }}

    /* Dialogs ------------------------------------------------------------ */
    QWidget#DialogHeader {{
        background: {c['surface']};
        border-bottom: 1px solid {c['border']};
    }}
    QLabel#DialogTitle {{ color: {c['text']}; font-size: {sp(14)}px; font-weight: 850; }}
    QLabel#DialogSubtitle {{ color: {c['text_dim']}; font-size: {sp(10)}px; }}
    QPushButton#DialogCloseButton {{
        background: transparent;
        border: 1px solid transparent;
        padding: 0;
        min-height: {sp(30)}px;
        border-radius: {r['sm']}px;
    }}
    QPushButton#DialogCloseButton:hover {{ background: {c['surface_2']}; border-color: {c['border']}; }}
    QFrame#SettingsNav {{ background: {c['bg_alt']}; border-right: 1px solid {c['border']}; }}
    QPushButton#SettingsNavItem {{
        background: transparent;
        border: 1px solid transparent;
        color: {c['text_muted']};
        border-radius: {r['sm']}px;
        padding: {sp(8)}px {sp(10)}px;
        text-align: left;
        min-height: {sp(34)}px;
    }}
    QPushButton#SettingsNavItem:hover {{ background: {c['surface']}; color: {c['text']}; }}
    QPushButton#SettingsNavItem:checked {{ background: {c['accent_soft']}; color: {c['accent']}; border-color: rgba(108,140,255,0.26); }}

    /* Scrollbars --------------------------------------------------------- */
    QScrollBar:vertical {{ background: transparent; width: {sp(10)}px; margin: {sp(2)}px; }}
    QScrollBar::handle:vertical {{ background: {c['border_strong']}; border-radius: {sp(5)}px; min-height: {sp(28)}px; }}
    QScrollBar::handle:vertical:hover {{ background: {c['text_dim']}; }}
    QScrollBar:horizontal {{ background: transparent; height: {sp(10)}px; margin: {sp(2)}px; }}
    QScrollBar::handle:horizontal {{ background: {c['border_strong']}; border-radius: {sp(5)}px; min-width: {sp(28)}px; }}
    QScrollBar::handle:horizontal:hover {{ background: {c['text_dim']}; }}
    QScrollBar::add-line, QScrollBar::sub-line {{ width: 0; height: 0; }}
    QScrollBar::add-page, QScrollBar::sub-page {{ background: transparent; }}
    QSplitter::handle {{ background: transparent; }}
    QSplitter::handle:horizontal {{ width: {sp(8)}px; }}

    /* Status / tooltip --------------------------------------------------- */
    QStatusBar {{
        background: {c['bg_alt']};
        border-top: 1px solid {c['border']};
        color: {c['text_dim']};
        font-size: {sp(10)}px;
        padding: 0 {sp(8)}px;
    }}
    QStatusBar::item {{ border: none; }}
    QToolTip {{
        background: {c['surface_2']};
        color: {c['text']};
        border: 1px solid {c['border_strong']};
        border-radius: {r['sm']}px;
        padding: {sp(6)}px {sp(8)}px;
        font-size: {sp(11)}px;
    }}
    """
