"""Diálogos do HoraFolio: consistentes com o shell e orientados à tarefa."""

from __future__ import annotations

from datetime import datetime
import math
from pathlib import Path

from PySide6.QtCore import QPoint, QSize, Qt, QTimer, QUrl, Signal
from PySide6.QtGui import QDesktopServices, QImageReader, QPixmap
from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QDialog,
    QFileDialog,
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPlainTextEdit,
    QPushButton,
    QScrollArea,
    QStackedWidget,
    QVBoxLayout,
    QWidget,
)

from ..constants import dia_semana_pt
from ..models import AppSettings, AutomationConfig, ProfileConfig, TimesheetRecord
from ..ocr.engine import check_tesseract
from ..ocr.preprocess import is_supported_image
from .theme import COLORS, RADIUS, SPACE, scaled
from .widgets import DetailRow, IconBadge, SectionCard, ShortcutHint, StateBanner, make_line_icon


def resolve_image_path(source: str) -> Path | None:
    if not source or source in {"manual", "texto_importado"}:
        return None
    path = Path(source)
    if path.is_file() and is_supported_image(path):
        return path
    return None


def _parent_window_geometry(parent: QWidget | None) -> tuple[int, int, int, int]:
    if parent is not None:
        window = parent.window()
        if window is not None:
            geo = window.frameGeometry()
            return geo.x(), geo.y(), geo.width(), geo.height()
    from PySide6.QtWidgets import QApplication

    screen = QApplication.primaryScreen()
    if screen:
        avail = screen.availableGeometry()
        return avail.x(), avail.y(), avail.width(), avail.height()
    return 0, 0, 960, 720


class DialogHeader(QWidget):
    """Header arrastável usado por todos os modais frameless."""

    close_requested = Signal()

    def __init__(self, title: str, subtitle: str = "", parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._drag_offset: QPoint | None = None
        self.setObjectName("DialogHeader")
        layout = QHBoxLayout(self)
        layout.setContentsMargins(scaled(SPACE["lg"]), scaled(10), scaled(SPACE["sm"]), scaled(10))
        layout.setSpacing(scaled(SPACE["sm"]))

        text = QVBoxLayout()
        text.setSpacing(0)
        title_label = QLabel(title)
        title_label.setObjectName("DialogTitle")
        text.addWidget(title_label)
        if subtitle:
            subtitle_label = QLabel(subtitle)
            subtitle_label.setObjectName("DialogSubtitle")
            subtitle_label.setWordWrap(False)
            text.addWidget(subtitle_label)
        layout.addLayout(text, 1)

        close_btn = QPushButton("")
        close_btn.setObjectName("DialogCloseButton")
        close_btn.setIcon(make_line_icon("close"))
        close_btn.setIconSize(QSize(scaled(16), scaled(16)))
        close_btn.setFixedSize(scaled(32), scaled(30))
        close_btn.setToolTip("Fechar")
        close_btn.clicked.connect(self.close_requested.emit)
        layout.addWidget(close_btn, 0, Qt.AlignTop)

    def mousePressEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.LeftButton:
            window = self.window()
            self._drag_offset = event.globalPosition().toPoint() - window.frameGeometry().topLeft()
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event) -> None:  # noqa: N802
        if event.buttons() & Qt.LeftButton and self._drag_offset is not None:
            self.window().move(event.globalPosition().toPoint() - self._drag_offset)
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event) -> None:  # noqa: N802
        self._drag_offset = None
        super().mouseReleaseEvent(event)


class _BaseDialog(QDialog):
    """Base visual comum com header, borda e centralização."""

    def __init__(self, parent: QWidget | None, title: str, subtitle: str = "") -> None:
        super().__init__(parent)
        self.setWindowTitle(title)
        self.setWindowModality(Qt.WindowModal)
        self.setWindowFlags(Qt.Dialog | Qt.FramelessWindowHint)
        self._positioned = False

        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)
        self.header = DialogHeader(title, subtitle)
        self.header.close_requested.connect(self.reject)
        outer.addWidget(self.header)
        host = QWidget()
        self.body = QVBoxLayout(host)
        self.body.setContentsMargins(scaled(SPACE["xl"]), scaled(SPACE["lg"]),
                                     scaled(SPACE["xl"]), scaled(SPACE["lg"]))
        self.body.setSpacing(scaled(SPACE["lg"]))
        outer.addWidget(host, 1)
        self.setStyleSheet(
            f"QDialog {{ background:{COLORS['bg']}; border:1px solid {COLORS['border_strong']};"
            f"border-radius:{RADIUS['lg']}px; }}"
        )

    def showEvent(self, event) -> None:  # noqa: N802
        super().showEvent(event)
        if not self._positioned:
            self._center_on_parent()
            self._positioned = True

    def _center_on_parent(self) -> None:
        px, py, pw, ph = _parent_window_geometry(self.parentWidget())
        self.move(px + max(0, (pw - self.width()) // 2), py + max(0, (ph - self.height()) // 2))


class MessageDialog(_BaseDialog):
    """Mensagem/confirm dialog sem bloqueios visuais do QMessageBox nativo."""

    def __init__(self, parent: QWidget | None, title: str, message: str, kind: str = "info",
                 confirm_text: str = "OK", cancel_text: str | None = None) -> None:
        super().__init__(parent, title)
        self.setMinimumWidth(scaled(440))
        self.setMaximumWidth(scaled(620))
        icon_name = "check" if kind == "success" else "warning" if kind in {"warning", "error"} else "info"
        icon_kind = kind if kind in {"success", "warning", "error"} else "accent"

        content = QHBoxLayout()
        content.setSpacing(scaled(SPACE["md"]))
        content.addWidget(IconBadge(icon_name, icon_kind, 44), 0, Qt.AlignTop)
        label = QLabel(message)
        label.setObjectName("Body")
        label.setWordWrap(True)
        label.setTextInteractionFlags(Qt.TextSelectableByMouse)
        content.addWidget(label, 1)
        self.body.addLayout(content)

        buttons = QHBoxLayout()
        buttons.addStretch(1)
        if cancel_text:
            cancel = QPushButton(cancel_text)
            cancel.setObjectName("Ghost")
            cancel.clicked.connect(self.reject)
            buttons.addWidget(cancel)
        confirm = QPushButton(confirm_text)
        confirm.setObjectName("Accent")
        confirm.clicked.connect(self.accept)
        buttons.addWidget(confirm)
        self.body.addLayout(buttons)

    @staticmethod
    def show_message(parent: QWidget | None, title: str, message: str, kind: str = "info") -> None:
        MessageDialog(parent, title, message, kind).exec()

    @staticmethod
    def ask(parent: QWidget | None, title: str, message: str, confirm_text: str = "Confirmar",
            cancel_text: str = "Cancelar", kind: str = "warning") -> bool:
        return MessageDialog(parent, title, message, kind, confirm_text, cancel_text).exec() == QDialog.Accepted


class ImageViewerDialog(_BaseDialog):
    """Visualizador com fit, 100% e zoom, sem decodificar imagens gigantes à toa."""

    def __init__(self, parent: QWidget | None, image_path: Path) -> None:
        super().__init__(parent, image_path.name, str(image_path))
        px, py, pw, ph = _parent_window_geometry(parent)
        dialog_w = max(scaled(620), int(pw * 0.84))
        dialog_h = max(scaled(440), int(ph * 0.84))
        self.resize(dialog_w, dialog_h)
        self.move(px + (pw - dialog_w) // 2, py + (ph - dialog_h) // 2)
        self._positioned = True
        self._image_path = image_path
        self._fit_mode = True
        self._zoom = 1.0

        reader = QImageReader(str(image_path))
        reader.setAutoTransform(True)
        source_size = reader.size()
        if source_size.isValid():
            # Mantém detalhes suficientes para zoom sem deixar um print extremo
            # alocar memória ilimitada no simples ato de abrir o inspector.
            max_pixels = 10_000_000
            pixels = source_size.width() * source_size.height()
            preview_size = source_size
            if pixels > max_pixels:
                factor = math.sqrt(max_pixels / pixels)
                preview_size = QSize(max(1, int(source_size.width() * factor)), max(1, int(source_size.height() * factor)))
            reader.setScaledSize(preview_size)
            image = reader.read()
            self._original_pixmap = QPixmap.fromImage(image) if not image.isNull() else QPixmap()
        else:
            self._original_pixmap = QPixmap()

        toolbar = QHBoxLayout()
        toolbar.setSpacing(scaled(SPACE["xs"]))
        self.btn_zoom_out = QPushButton("−")
        self.btn_zoom_out.setObjectName("ToolbarButton")
        self.btn_zoom_out.setToolTip("Diminuir zoom")
        self.btn_zoom_out.clicked.connect(lambda: self._change_zoom(-0.20))
        self.zoom_label = QLabel("Ajustar")
        self.zoom_label.setObjectName("Mono")
        self.zoom_label.setMinimumWidth(scaled(72))
        self.zoom_label.setAlignment(Qt.AlignCenter)
        self.btn_zoom_in = QPushButton("+")
        self.btn_zoom_in.setObjectName("ToolbarButton")
        self.btn_zoom_in.setToolTip("Aumentar zoom")
        self.btn_zoom_in.clicked.connect(lambda: self._change_zoom(0.20))
        self.btn_fit = QPushButton("Ajustar")
        self.btn_fit.setObjectName("ToolbarButton")
        self.btn_fit.clicked.connect(self._fit)
        self.btn_actual = QPushButton("100%")
        self.btn_actual.setObjectName("ToolbarButton")
        self.btn_actual.clicked.connect(self._actual_size)
        toolbar.addWidget(self.btn_zoom_out)
        toolbar.addWidget(self.zoom_label)
        toolbar.addWidget(self.btn_zoom_in)
        toolbar.addWidget(self.btn_fit)
        toolbar.addWidget(self.btn_actual)
        toolbar.addStretch(1)
        btn_system = QPushButton("Abrir no sistema")
        btn_system.setObjectName("Ghost")
        btn_system.setIcon(make_line_icon("export"))
        btn_system.clicked.connect(lambda: QDesktopServices.openUrl(QUrl.fromLocalFile(str(self._image_path))))
        toolbar.addWidget(btn_system)
        self.body.addLayout(toolbar)

        if self._original_pixmap.isNull():
            error = StateBanner("Imagem indisponível", "Não foi possível decodificar este arquivo.", "error", "warning")
            self.body.addWidget(error, 1)
            self._scroll = None
            self._image_label = None
        else:
            self._scroll = QScrollArea()
            self._scroll.setWidgetResizable(False)
            self._scroll.setAlignment(Qt.AlignCenter)
            self._scroll.setFrameShape(QScrollArea.NoFrame)
            self._image_label = QLabel()
            self._image_label.setAlignment(Qt.AlignCenter)
            self._scroll.setWidget(self._image_label)
            self.body.addWidget(self._scroll, 1)

        hint = QLabel("Ctrl + roda do mouse também controla o zoom. O modo Ajustar acompanha o tamanho da janela.")
        hint.setObjectName("Dim")
        self.body.addWidget(hint)

    def showEvent(self, event) -> None:  # noqa: N802
        super().showEvent(event)
        QTimer.singleShot(0, self._render_image)

    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        if self._fit_mode:
            self._render_image()

    def wheelEvent(self, event) -> None:  # noqa: N802
        if event.modifiers() & Qt.ControlModifier:
            self._change_zoom(0.10 if event.angleDelta().y() > 0 else -0.10)
            event.accept()
            return
        super().wheelEvent(event)

    def _fit(self) -> None:
        self._fit_mode = True
        self.zoom_label.setText("Ajustar")
        self._render_image()

    def _actual_size(self) -> None:
        self._fit_mode = False
        self._zoom = 1.0
        self._render_image()

    def _change_zoom(self, delta: float) -> None:
        self._fit_mode = False
        self._zoom = max(0.20, min(2.5, self._zoom + delta))
        self._render_image()

    def _render_image(self) -> None:
        if self._scroll is None or self._image_label is None or self._original_pixmap.isNull():
            return
        if self._fit_mode:
            viewport = self._scroll.viewport().size()
            if viewport.width() < 8 or viewport.height() < 8:
                return
            target = self._original_pixmap.size().scaled(viewport, Qt.KeepAspectRatio)
            fitted = self._original_pixmap.scaled(target, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            self.zoom_label.setText("Ajustar")
        else:
            source = self._original_pixmap.size()
            target = QSize(max(1, int(source.width() * self._zoom)), max(1, int(source.height() * self._zoom)))
            # O zoom nunca deve recriar o mesmo risco de memória que o viewer
            # evita na decodificação inicial. Limite o bitmap renderizado.
            max_render_pixels = 16_000_000
            pixels = target.width() * target.height()
            if pixels > max_render_pixels:
                factor = math.sqrt(max_render_pixels / pixels)
                target = QSize(max(1, int(target.width() * factor)), max(1, int(target.height() * factor)))
            fitted = self._original_pixmap.scaled(target, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            self.zoom_label.setText(f"{round(self._zoom * 100)}%")
        self._image_label.setPixmap(fitted)
        self._image_label.resize(fitted.size())

    @staticmethod
    def show_image(parent: QWidget | None, image_path: Path) -> None:
        ImageViewerDialog(parent, image_path).exec()


def open_image_path(parent: QWidget | None, source: str | Path) -> bool:
    path = source if isinstance(source, Path) else resolve_image_path(str(source))
    if path is None:
        path = Path(source) if source else None
    if path is None or not path.is_file() or not is_supported_image(path):
        MessageDialog.show_message(parent, "Print indisponível", "Não há uma imagem associada a este registro.", "warning")
        return False
    ImageViewerDialog.show_image(parent, path)
    return True


class RecordDialog(_BaseDialog):
    """Criação/edição de um dia com validação inline e contexto da fonte."""

    def __init__(self, parent: QWidget | None, title: str, initial: TimesheetRecord | None = None) -> None:
        super().__init__(parent, title, "Decisões manuais têm prioridade sobre novas importações.")
        self.setMinimumWidth(scaled(590))
        self._initial = initial
        self._editing = initial is not None
        self.result_record: TimesheetRecord | None = None

        if initial:
            source_card = SectionCard("Origem", "Contexto preservado mesmo depois de editar o registro.", padding=scaled(12))
            source_card.body().addWidget(DetailRow("Fonte", Path(initial.source_file).name if initial.source_file else "Manual"))
            confidence = f"{initial.confidence:.0f}%" if isinstance(initial.confidence, (int, float)) else "Não disponível"
            source_card.body().addWidget(DetailRow("Confiança", confidence))
            self.body.addWidget(source_card)

        form_card = SectionCard("Dados do dia")
        form = QFormLayout()
        form.setSpacing(scaled(SPACE["md"]))
        form.setLabelAlignment(Qt.AlignLeft | Qt.AlignVCenter)

        self.chk_include = QCheckBox("Aprovar este dia para o Excel")
        self.chk_include.setChecked(initial.include if initial else True)
        self.edit_date = QLineEdit(initial.data.strftime("%d/%m/%Y") if initial else "")
        self.edit_date.setPlaceholderText("DD/MM/AAAA")
        self.edit_weekday = QLineEdit(initial.dia_semana if initial else "")
        self.edit_weekday.setReadOnly(True)
        self.edit_weekday.setPlaceholderText("Calculado pela data")
        self.edit_date.textChanged.connect(self._sync_weekday_from_date)
        self.edit_worked = QLineEdit(initial.worked_hhmm if initial else "")
        self.edit_worked.setPlaceholderText("H:MM · exemplo: 8:30")
        self.edit_activity = QLineEdit(initial.atividade if initial else "")
        self.edit_activity.setPlaceholderText("Vazio = atividade padrão do perfil")
        self.combo_status = QComboBox()
        for label, value in (("Pronto", "ok"), ("Precisa revisar", "revisar"), ("Ignorado", "ignorado")):
            self.combo_status.addItem(label, value)
        if initial:
            idx = self.combo_status.findData(initial.status)
            if idx >= 0:
                self.combo_status.setCurrentIndex(idx)

        form.addRow("", self.chk_include)
        form.addRow("Data", self.edit_date)
        form.addRow("Dia da semana", self.edit_weekday)
        form.addRow("Horas trabalhadas", self.edit_worked)
        if not self._editing:
            form.addRow("Status inicial", self.combo_status)
        form.addRow("Atividade / entrega", self.edit_activity)
        form_card.body().addLayout(form)

        notes_label = QLabel("Observações")
        notes_label.setObjectName("Dim")
        self.edit_notes = QPlainTextEdit()
        self.edit_notes.setPlaceholderText("Uma observação por linha. Você também pode separar por ponto e vírgula.")
        self.edit_notes.setPlainText("\n".join(initial.notes) if initial else "")
        self.edit_notes.setMaximumHeight(scaled(110))
        form_card.body().addWidget(notes_label)
        form_card.body().addWidget(self.edit_notes)
        self.body.addWidget(form_card)

        self.error_banner = StateBanner("", "", "error", "warning")
        self.error_banner.hide()
        self.body.addWidget(self.error_banner)

        buttons = QHBoxLayout()
        buttons.addStretch(1)
        cancel = QPushButton("Cancelar")
        cancel.setObjectName("Ghost")
        cancel.clicked.connect(self.reject)
        save = QPushButton("Salvar alterações" if initial else "Adicionar registro")
        save.setObjectName("Accent")
        save.clicked.connect(self._on_accept)
        buttons.addWidget(cancel)
        buttons.addWidget(save)
        self.body.addLayout(buttons)
        self._sync_weekday_from_date()

    def _show_error(self, message: str) -> None:
        self.error_banner.set_state("Confira os dados", message, "error", "warning")
        self.error_banner.show()

    def _sync_weekday_from_date(self, *_args) -> None:
        try:
            parsed_date = datetime.strptime(self.edit_date.text().strip(), "%d/%m/%Y").date()
        except ValueError:
            if not self.edit_date.text().strip():
                self.edit_weekday.clear()
            return
        self.edit_weekday.setText(dia_semana_pt(parsed_date))

    def _on_accept(self) -> None:
        try:
            parsed_date = datetime.strptime(self.edit_date.text().strip(), "%d/%m/%Y").date()
        except ValueError:
            self._show_error("A data precisa estar no formato DD/MM/AAAA.")
            return

        worked_text = self.edit_worked.text().strip()
        worked_minutes: int | None = None
        if worked_text:
            try:
                h_text, m_text = worked_text.split(":", 1)
                h, m = int(h_text), int(m_text)
                if h < 0 or m < 0 or m >= 60 or h > 24 or (h == 24 and m > 0):
                    raise ValueError
                worked_minutes = h * 60 + m
            except ValueError:
                self._show_error("Use horas no formato H:MM entre 0:00 e 24:00, por exemplo 8:30.")
                return

        if self._editing:
            status = "editado"
        else:
            status = str(self.combo_status.currentData() or "ok")
        include = self.chk_include.isChecked()
        if status == "ignorado":
            include = False
        notes_text = self.edit_notes.toPlainText().replace(";", "\n")
        notes = [line.strip() for line in notes_text.splitlines() if line.strip()]
        self.result_record = TimesheetRecord(
            data=parsed_date,
            dia_semana=dia_semana_pt(parsed_date),
            worked_minutes=worked_minutes,
            include=include,
            status=status,
            source_file=self._initial.source_file if self._initial else "manual",
            tipo=self._initial.tipo if self._initial else "manual",
            pontos=list(self._initial.pontos) if self._initial else [],
            notes=notes,
            confidence=self._initial.confidence if self._initial else None,
            atividade=self.edit_activity.text().strip(),
            manual_decision=True,
        )
        self.accept()

    @staticmethod
    def get_record(parent: QWidget | None, title: str, initial: TimesheetRecord | None = None) -> TimesheetRecord | None:
        dialog = RecordDialog(parent, title, initial)
        return dialog.result_record if dialog.exec() == QDialog.Accepted else None


class TextImportDialog(_BaseDialog):
    """Importa texto bruto sem exigir imagens/Tesseract."""

    def __init__(self, parent: QWidget | None) -> None:
        super().__init__(parent, "Importar texto", "Cole uma leitura OCR ou texto copiado do Banco de Horas.")
        self.resize(scaled(720), scaled(520))
        self.text_value = ""
        hint = StateBanner(
            "O parser é o mesmo do OCR",
            "Cole vários cartões de uma vez. Datas e campos Trabalhou reconhecidos serão consolidados automaticamente.",
            "info",
            "info",
        )
        self.body.addWidget(hint)
        self.editor = QPlainTextEdit()
        self.editor.setPlaceholderText("Cole aqui o texto bruto…")
        self.body.addWidget(self.editor, 1)
        buttons = QHBoxLayout()
        buttons.addStretch(1)
        cancel = QPushButton("Cancelar")
        cancel.setObjectName("Ghost")
        cancel.clicked.connect(self.reject)
        import_btn = QPushButton("Importar texto")
        import_btn.setObjectName("Accent")
        import_btn.clicked.connect(self._on_accept)
        buttons.addWidget(cancel)
        buttons.addWidget(import_btn)
        self.body.addLayout(buttons)

    def _on_accept(self) -> None:
        self.text_value = self.editor.toPlainText().strip()
        self.accept()

    @staticmethod
    def get_text(parent: QWidget | None) -> str:
        dialog = TextImportDialog(parent)
        return dialog.text_value if dialog.exec() == QDialog.Accepted else ""


class ShortcutDialog(_BaseDialog):
    """Mapa de atalhos descobrível pela própria interface."""

    def __init__(self, parent: QWidget | None) -> None:
        super().__init__(parent, "Atalhos do teclado", "Ações rápidas para fechar o mês com menos cliques.")
        self.resize(scaled(760), scaled(560))
        self.setMinimumSize(scaled(680), scaled(500))

        intro = StateBanner(
            "Tudo continua disponível pelo mouse",
            "Os atalhos aceleram o fluxo, mas nenhuma ação depende deles.",
            "info",
            "info",
        )
        self.body.addWidget(intro)

        columns = QHBoxLayout()
        columns.setSpacing(scaled(SPACE["md"]))
        columns.addWidget(self._shortcut_card("Global", (
            ("Ctrl + 1 / 2 / 3", "Ir para Entrada, Revisão ou Excel"),
            ("Ctrl + N", "Começar um novo mês"),
            ("Ctrl + ,", "Abrir Preferências"),
            ("Ctrl + /", "Abrir esta referência"),
        )), 1)
        columns.addWidget(self._shortcut_card("Entrada", (
            ("Ctrl + O", "Adicionar prints"),
            ("Ctrl + Shift + O", "Adicionar uma pasta"),
            ("Ctrl + I", "Importar espelho"),
            ("Ctrl + Shift + I", "Colar texto"),
        )), 1)
        columns.addWidget(self._shortcut_card("Revisão", (
            ("Ctrl + F", "Buscar registros"),
            ("Enter", "Editar o dia selecionado"),
            ("Ctrl + Enter", "Aprovar seleção"),
            ("Ctrl + Backspace", "Ignorar seleção"),
            ("Delete", "Excluir seleção"),
        )), 1)
        self.body.addLayout(columns, 1)

        close_btn = QPushButton("Fechar")
        close_btn.setObjectName("Accent")
        close_btn.clicked.connect(self.accept)
        footer = QHBoxLayout()
        footer.addStretch(1)
        footer.addWidget(close_btn)
        self.body.addLayout(footer)

    @staticmethod
    def _shortcut_card(title: str, items: tuple[tuple[str, str], ...]) -> SectionCard:
        card = SectionCard(title)
        for sequence, description in items:
            row = QHBoxLayout()
            row.setSpacing(scaled(SPACE["sm"]))
            hint = ShortcutHint(sequence)
            hint.setMinimumWidth(scaled(108))
            description_label = QLabel(description)
            description_label.setObjectName("Subtle")
            description_label.setWordWrap(True)
            row.addWidget(hint, 0, Qt.AlignTop)
            row.addWidget(description_label, 1, Qt.AlignTop)
            card.body().addLayout(row)
        card.body().addStretch(1)
        return card

    @staticmethod
    def show_shortcuts(parent: QWidget | None) -> None:
        ShortcutDialog(parent).exec()


class SettingsDialog(_BaseDialog):
    """Central de preferências com navegação lateral por contexto."""

    def __init__(self, parent: QWidget | None, current: AppSettings) -> None:
        super().__init__(parent, "Preferências", "Perfil, OCR e automações do seu fluxo mensal.")
        self.resize(scaled(820), scaled(590))
        self.setMinimumSize(scaled(720), scaled(520))
        self._current = current
        self.updated: AppSettings | None = None

        content = QHBoxLayout()
        content.setSpacing(0)
        nav = QFrame()
        nav.setObjectName("SettingsNav")
        nav.setFixedWidth(scaled(180))
        nav_layout = QVBoxLayout(nav)
        nav_layout.setContentsMargins(scaled(10), scaled(12), scaled(10), scaled(12))
        nav_layout.setSpacing(scaled(4))
        label = QLabel("CATEGORIAS")
        label.setObjectName("RailEyebrow")
        nav_layout.addWidget(label)

        self.stack = QStackedWidget()
        pages = [
            ("user", "Perfil", self._scrollable_page(self._build_profile_page())),
            ("search", "OCR", self._scrollable_page(self._build_ocr_page())),
            ("automation", "Automação", self._scrollable_page(self._build_automation_page())),
        ]
        self._nav_buttons: list[QPushButton] = []
        for index, (icon, text, page) in enumerate(pages):
            button = QPushButton(text)
            button.setObjectName("SettingsNavItem")
            button.setCheckable(True)
            button.setAutoExclusive(True)
            button.setIcon(make_line_icon(icon))
            button.clicked.connect(lambda _checked=False, i=index: self.stack.setCurrentIndex(i))
            nav_layout.addWidget(button)
            self._nav_buttons.append(button)
            self.stack.addWidget(page)
        nav_layout.addStretch(1)
        self._nav_buttons[0].setChecked(True)
        content.addWidget(nav)
        content.addWidget(self.stack, 1)
        self.body.addLayout(content, 1)

        footer = QHBoxLayout()
        self.status_label = QLabel("")
        self.status_label.setObjectName("Subtle")
        self.status_label.setWordWrap(True)
        footer.addWidget(self.status_label, 1)
        cancel = QPushButton("Cancelar")
        cancel.setObjectName("Ghost")
        cancel.clicked.connect(self.reject)
        save = QPushButton("Salvar preferências")
        save.setObjectName("Accent")
        save.clicked.connect(self._on_accept)
        footer.addWidget(cancel)
        footer.addWidget(save)
        self.body.addLayout(footer)

    @staticmethod
    def _scrollable_page(page: QWidget) -> QScrollArea:
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.setWidget(page)
        return scroll

    def _page(self, title: str, subtitle: str) -> tuple[QWidget, QVBoxLayout]:
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(scaled(SPACE["lg"]), scaled(SPACE["sm"]), 0, scaled(SPACE["sm"]))
        layout.setSpacing(scaled(SPACE["md"]))
        heading = QLabel(title)
        heading.setObjectName("H1")
        caption = QLabel(subtitle)
        caption.setObjectName("Subtle")
        caption.setWordWrap(True)
        layout.addWidget(heading)
        layout.addWidget(caption)
        return page, layout

    def _build_profile_page(self) -> QWidget:
        page, layout = self._page("Perfil do timesheet", "Esses dados aparecem no Excel e ficam salvos para os próximos meses.")
        card = SectionCard()
        form = QFormLayout()
        form.setSpacing(scaled(SPACE["md"]))
        self.edit_colaborador = QLineEdit(self._current.profile.colaborador)
        self.edit_cargo = QLineEdit(self._current.profile.cargo)
        self.edit_modalidade = QLineEdit(self._current.profile.modalidade)
        self.edit_atividade_padrao = QLineEdit(self._current.profile.atividade_padrao)
        self.edit_atividade_padrao.setPlaceholderText("Ex.: Desenvolvimento e manutenção de software")
        form.addRow("Colaborador", self.edit_colaborador)
        form.addRow("Cargo", self.edit_cargo)
        form.addRow("Modalidade", self.edit_modalidade)
        form.addRow("Atividade padrão", self.edit_atividade_padrao)
        card.body().addLayout(form)
        layout.addWidget(card)
        layout.addStretch(1)
        return page

    def _build_ocr_page(self) -> QWidget:
        page, layout = self._page("OCR local", "Só é necessário para prints. Importar espelho de ponto funciona sem Tesseract.")
        card = SectionCard("Tesseract")
        self.edit_tesseract = QLineEdit(self._current.tesseract_cmd)
        self.edit_tesseract.setPlaceholderText(r"C:\Program Files\Tesseract-OCR\tesseract.exe")
        browse = QPushButton("Procurar")
        browse.setObjectName("ToolbarButton")
        browse.clicked.connect(self._browse_tesseract)
        path_row = QHBoxLayout()
        path_row.addWidget(self.edit_tesseract, 1)
        path_row.addWidget(browse)
        path_widget = QWidget()
        path_widget.setLayout(path_row)

        self.edit_lang = QLineEdit(self._current.tesseract_lang)
        self.edit_lang.setPlaceholderText("por+eng")
        test = QPushButton("Testar agora")
        test.setObjectName("ToolbarButton")
        test.clicked.connect(self._test_ocr)
        lang_row = QHBoxLayout()
        lang_row.addWidget(self.edit_lang, 1)
        lang_row.addWidget(test)
        lang_widget = QWidget()
        lang_widget.setLayout(lang_row)

        form = QFormLayout()
        form.setSpacing(scaled(SPACE["md"]))
        form.addRow("Executável", path_widget)
        form.addRow("Idiomas", lang_widget)
        card.body().addLayout(form)
        layout.addWidget(card)
        self.ocr_result = StateBanner("", "", "info", "info")
        self.ocr_result.hide()
        layout.addWidget(self.ocr_result)
        layout.addStretch(1)
        return page

    def _build_automation_page(self) -> QWidget:
        page, layout = self._page("Automação", "Reduza cliques recorrentes sem deixar decisões críticas invisíveis.")
        config = self._current.automation
        session = SectionCard("Sessão e revisão")
        self.chk_autosave = QCheckBox("Salvar o trabalho automaticamente")
        self.chk_autosave.setChecked(config.autosave_session)
        self.chk_restore = QCheckBox("Recuperar a última sessão ao abrir")
        self.chk_restore.setChecked(config.restore_session and config.autosave_session)
        self.chk_restore.setEnabled(config.autosave_session)
        self.chk_autosave.toggled.connect(self._sync_restore_with_autosave)
        self.chk_focus_issues = QCheckBox("Abrir a revisão focando apenas nas pendências")
        self.chk_focus_issues.setChecked(config.focus_review_issues)
        for widget in (self.chk_autosave, self.chk_restore, self.chk_focus_issues):
            session.body().addWidget(widget)
        layout.addWidget(session)

        flow = SectionCard("Entrada e saída")
        self.chk_auto_ocr = QCheckBox("Iniciar OCR automaticamente ao adicionar novos prints")
        self.chk_auto_ocr.setChecked(config.auto_start_ocr)
        self.chk_recursive = QCheckBox("Incluir subpastas ao importar uma pasta")
        self.chk_recursive.setChecked(config.recursive_folder_import)
        self.chk_open_output = QCheckBox("Abrir a pasta depois de gerar o Excel")
        self.chk_open_output.setChecked(config.open_output_folder)
        for widget in (self.chk_auto_ocr, self.chk_recursive, self.chk_open_output):
            flow.body().addWidget(widget)
        output_label = QLabel("Pasta padrão")
        output_label.setObjectName("Dim")
        self.edit_output_dir = QLineEdit(config.output_dir)
        self.edit_output_dir.setPlaceholderText("Automático: Documentos/Timesheets")
        output_browse = QPushButton("Escolher")
        output_browse.setObjectName("ToolbarButton")
        output_browse.clicked.connect(self._browse_output_dir)
        output_row = QHBoxLayout()
        output_row.addWidget(self.edit_output_dir, 1)
        output_row.addWidget(output_browse)
        flow.body().addWidget(output_label)
        flow.body().addLayout(output_row)
        layout.addWidget(flow)
        layout.addStretch(1)
        return page

    def _sync_restore_with_autosave(self, enabled: bool) -> None:
        self.chk_restore.setEnabled(enabled)
        if not enabled:
            self.chk_restore.setChecked(False)

    def _browse_output_dir(self) -> None:
        initial = self.edit_output_dir.text().strip() or self._current.automation.last_output_dir
        folder = QFileDialog.getExistingDirectory(self, "Pasta padrão dos timesheets", initial)
        if folder:
            self.edit_output_dir.setText(folder)

    def _browse_tesseract(self) -> None:
        filename, _ = QFileDialog.getOpenFileName(
            self, "Selecionar executável do Tesseract", "", "Executável (*.exe);;Todos os arquivos (*.*)"
        )
        if filename:
            self.edit_tesseract.setText(filename)

    def _test_ocr(self) -> None:
        ok, message = check_tesseract(self.edit_tesseract.text(), self.edit_lang.text())
        self.ocr_result.set_state(
            "OCR disponível" if ok else "OCR indisponível",
            message,
            "success" if ok else "error",
            "check" if ok else "warning",
        )
        self.ocr_result.show()
        self.status_label.setText("Teste concluído.")

    def _on_accept(self) -> None:
        self.updated = AppSettings(
            tesseract_cmd=self.edit_tesseract.text().strip(),
            tesseract_lang=self.edit_lang.text().strip() or "por+eng",
            profile=ProfileConfig(
                colaborador=self.edit_colaborador.text().strip() or "Brenno C. Torquato",
                cargo=self.edit_cargo.text().strip() or "Desenvolvedor Jr",
                modalidade=self.edit_modalidade.text().strip() or "Presencial",
                atividade_padrao=self.edit_atividade_padrao.text().strip(),
            ),
            automation=AutomationConfig(
                autosave_session=self.chk_autosave.isChecked(),
                restore_session=self.chk_autosave.isChecked() and self.chk_restore.isChecked(),
                focus_review_issues=self.chk_focus_issues.isChecked(),
                auto_start_ocr=self.chk_auto_ocr.isChecked(),
                recursive_folder_import=self.chk_recursive.isChecked(),
                open_output_folder=self.chk_open_output.isChecked(),
                output_dir=self.edit_output_dir.text().strip(),
                last_input_dir=self._current.automation.last_input_dir,
                last_output_dir=self._current.automation.last_output_dir,
            ),
        )
        self.accept()

    @staticmethod
    def edit_settings(parent: QWidget | None, current: AppSettings) -> AppSettings | None:
        dialog = SettingsDialog(parent, current)
        return dialog.updated if dialog.exec() == QDialog.Accepted else None
