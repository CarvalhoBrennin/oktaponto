"""Entrada de dados: prints, pastas, espelho e texto."""

from __future__ import annotations

import os
from pathlib import Path

from PySide6.QtCore import QSize, Qt, QThread, QTimer, Signal
from PySide6.QtGui import QIcon, QImageReader, QKeySequence, QPixmap, QShortcut
from PySide6.QtWidgets import (
    QAbstractItemView,
    QFileDialog,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QProgressBar,
    QPushButton,
    QSizePolicy,
    QStackedWidget,
    QVBoxLayout,
    QWidget,
)

from ...models import AppSettings, TimesheetRecord
from ...ocr.engine import resolve_tesseract_cmd
from ...ocr.preprocess import is_supported_image
from ..dialogs import ImageViewerDialog, MessageDialog
from ..theme import SPACE, scaled
from ..widgets import ActionCard, DropZone, EmptyState, PageHeader, SectionCard, StateBanner, make_line_icon
from ..workers import OcrWorker


class PrintsPage(QWidget):
    """Página de entrada; gerencia a fila de imagens e a execução do OCR."""

    records_ready = Signal(list)
    status_message = Signal(str)
    request_text_import = Signal()
    request_espelho_import = Signal()
    files_changed = Signal()
    input_directory_used = Signal(str)

    def __init__(self, get_settings, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._get_settings = get_settings
        self.image_paths: list[Path] = []
        self._thread: QThread | None = None
        self._worker: OcrWorker | None = None
        self._worker_warnings: list[str] = []
        self._pending_auto_ocr: list[Path] = []
        self._thumb_size = QSize(scaled(38), scaled(38))
        self._compact = False

        root = QVBoxLayout(self)
        root.setContentsMargins(scaled(SPACE["xl"]), scaled(SPACE["lg"]),
                                scaled(SPACE["xl"]), scaled(SPACE["lg"]))
        root.setSpacing(scaled(SPACE["lg"]))

        header = PageHeader(
            "1 · Entrada",
            "De onde vêm as horas?",
            "Use prints quando precisar do OCR ou pule direto para o espelho de ponto quando tiver o arquivo estruturado.",
        )
        root.addWidget(header)

        self.tip_banner = StateBanner(
            "Caminho mais rápido",
            "Se você já tem o Espelho de Ponto em XLSX/PDF, importe-o direto: é mais preciso e não usa OCR.",
            "info",
            "info",
        )
        root.addWidget(self.tip_banner)

        input_row = QHBoxLayout()
        input_row.setSpacing(scaled(SPACE["md"]))
        self.drop_zone = DropZone()
        self.drop_zone.setMinimumHeight(scaled(168))
        self.drop_zone.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.drop_zone.files_dropped.connect(self._add_paths)
        self.drop_zone.clicked.connect(self._browse_images)
        input_row.addWidget(self.drop_zone, 2)

        self.quick_actions = QWidget()
        self.quick_actions.setMaximumWidth(scaled(360))
        quick_layout = QVBoxLayout(self.quick_actions)
        quick_layout.setContentsMargins(0, 0, 0, 0)
        quick_layout.setSpacing(scaled(SPACE["sm"]))
        self.card_espelho = ActionCard(
            "spreadsheet",
            "Importar espelho",
            "XLSX, XLSM ou PDF · sem OCR",
            "Importar",
        )
        self.card_espelho.setToolTip("Ctrl+I")
        self.card_espelho.clicked.connect(self.request_espelho_import.emit)
        quick_layout.addWidget(self.card_espelho)
        self.card_text = ActionCard(
            "text",
            "Colar texto",
            "Use uma leitura OCR que você já possui",
            "Colar",
        )
        self.card_text.setToolTip("Ctrl+Shift+I")
        self.card_text.clicked.connect(self.request_text_import.emit)
        quick_layout.addWidget(self.card_text)
        input_row.addWidget(self.quick_actions, 1)
        root.addLayout(input_row)

        queue = SectionCard("Fila de prints", "A ordem não altera o resultado; arquivos repetidos são ignorados.")
        queue_body = queue.body()

        queue_toolbar = QHBoxLayout()
        queue_toolbar.setSpacing(scaled(SPACE["sm"]))
        self.queue_count = QLabel("0 prints")
        self.queue_count.setObjectName("H3")
        queue_toolbar.addWidget(self.queue_count)
        queue_toolbar.addStretch(1)
        self.btn_add = QPushButton("Adicionar")
        self.btn_add.setObjectName("ToolbarButton")
        self.btn_add.setIcon(make_line_icon("plus"))
        self.btn_add.setToolTip("Adicionar imagens · Ctrl+O")
        self.btn_add.clicked.connect(self._browse_images)
        queue_toolbar.addWidget(self.btn_add)
        self.btn_folder = QPushButton("Pasta")
        self.btn_folder.setObjectName("ToolbarButton")
        self.btn_folder.setIcon(make_line_icon("folder"))
        self.btn_folder.setToolTip("Adicionar uma pasta inteira · Ctrl+Shift+O")
        self.btn_folder.clicked.connect(self._browse_folder)
        queue_toolbar.addWidget(self.btn_folder)
        queue_body.addLayout(queue_toolbar)

        self.queue_stack = QStackedWidget()
        self.empty_state = EmptyState(
            "Nenhum print na fila",
            "Arraste imagens acima ou adicione uma pasta inteira. Se você importar um espelho, esta fila pode ficar vazia.",
            "image",
        )
        self.file_list = QListWidget()
        self.file_list.setAccessibleName("Fila de prints")
        self.file_list.setAccessibleDescription("Lista de imagens aguardando OCR. Use Delete para remover a seleção.")
        self.file_list.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.file_list.setIconSize(self._thumb_size)
        self.file_list.setMinimumHeight(scaled(170))
        self.file_list.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self.file_list.itemDoubleClicked.connect(self._open_selected_image)
        self.file_list.itemSelectionChanged.connect(self._refresh_selection_actions)
        self.file_list.setAccessibleName("Fila de prints para OCR")
        self.drop_zone.setAccessibleName("Área para adicionar prints")
        self._install_file_shortcuts()
        self.queue_stack.addWidget(self.empty_state)
        self.queue_stack.addWidget(self.file_list)
        queue_body.addWidget(self.queue_stack, 1)

        file_actions = QHBoxLayout()
        file_actions.setSpacing(scaled(SPACE["xs"]))
        self.selection_label = QLabel("Selecione um print para abrir ou remover")
        self.selection_label.setObjectName("Dim")
        file_actions.addWidget(self.selection_label)
        file_actions.addStretch(1)
        self.btn_open = QPushButton("Abrir")
        self.btn_open.setObjectName("Ghost")
        self.btn_open.setIcon(make_line_icon("eye"))
        self.btn_open.clicked.connect(self._open_selected_image)
        file_actions.addWidget(self.btn_open)
        self.btn_remove = QPushButton("Remover")
        self.btn_remove.setObjectName("Ghost")
        self.btn_remove.setIcon(make_line_icon("trash"))
        self.btn_remove.clicked.connect(self._remove_selected)
        file_actions.addWidget(self.btn_remove)
        self.btn_clear = QPushButton("Limpar fila")
        self.btn_clear.setObjectName("Danger")
        self.btn_clear.clicked.connect(self._clear)
        file_actions.addWidget(self.btn_clear)
        queue_body.addLayout(file_actions)
        root.addWidget(queue, 1)

        ocr_card = SectionCard()
        ocr_body = ocr_card.body()
        ocr_row = QHBoxLayout()
        ocr_row.setSpacing(scaled(SPACE["md"]))
        ocr_text = QVBoxLayout()
        ocr_text.setSpacing(scaled(3))
        self.ocr_title = QLabel("Leitura OCR local")
        self.ocr_title.setObjectName("H2")
        self.ocr_status = QLabel("Adicione prints para iniciar.")
        self.ocr_status.setObjectName("Subtle")
        self.ocr_status.setWordWrap(True)
        ocr_text.addWidget(self.ocr_title)
        ocr_text.addWidget(self.ocr_status)
        ocr_row.addLayout(ocr_text, 1)
        self.progress = QProgressBar()
        self.progress.setRange(0, 0)
        self.progress.setFixedWidth(scaled(160))
        self.progress.hide()
        ocr_row.addWidget(self.progress, 0, Qt.AlignVCenter)
        self.btn_run = QPushButton("Ler prints")
        self.btn_run.setObjectName("Accent")
        self.btn_run.setIcon(make_line_icon("search", "#08101E"))
        self.btn_run.clicked.connect(self._run_or_cancel_ocr)
        ocr_row.addWidget(self.btn_run, 0, Qt.AlignVCenter)
        ocr_body.addLayout(ocr_row)
        root.addWidget(ocr_card)

        self._refresh()


    def _install_file_shortcuts(self) -> None:
        self._file_shortcuts: list[QShortcut] = []
        for sequence, callback in (("Delete", self._remove_selected), ("Return", self._open_selected_image)):
            shortcut = QShortcut(QKeySequence(sequence), self.file_list)
            shortcut.setContext(Qt.ShortcutContext.WidgetWithChildrenShortcut)
            shortcut.activated.connect(callback)
            self._file_shortcuts.append(shortcut)

    # ------------------------------------------------------------------
    # Public shortcuts / responsive hooks
    # ------------------------------------------------------------------

    def browse_images(self) -> None:
        self._browse_images()

    def browse_folder(self) -> None:
        self._browse_folder()

    def refresh_from_settings(self) -> None:
        self._refresh()

    def set_compact_mode(self, compact: bool) -> None:
        self._compact = compact
        self.quick_actions.setMaximumWidth(scaled(300 if compact else 360))
        self.tip_banner.setVisible(not compact)

    # ------------------------------------------------------------------
    # File queue
    # ------------------------------------------------------------------

    def _browse_images(self) -> None:
        if self._thread is not None:
            return
        settings: AppSettings = self._get_settings()
        filenames, _ = QFileDialog.getOpenFileNames(
            self,
            "Adicionar prints do Banco de Horas",
            settings.automation.last_input_dir,
            "Imagens (*.png *.jpg *.jpeg *.webp *.bmp *.tif *.tiff);;Todos os arquivos (*.*)",
        )
        if filenames:
            self.input_directory_used.emit(str(Path(filenames[0]).parent))
        self._add_paths([Path(filename) for filename in filenames])

    def _browse_folder(self) -> None:
        if self._thread is not None:
            return
        settings: AppSettings = self._get_settings()
        folder = QFileDialog.getExistingDirectory(
            self, "Adicionar pasta com prints", settings.automation.last_input_dir
        )
        if not folder:
            return
        self.input_directory_used.emit(folder)
        self._add_paths([Path(folder)])

    def _expand_paths(self, paths: list[Path]) -> list[Path]:
        settings: AppSettings = self._get_settings()
        expanded: list[Path] = []
        unreadable = 0
        for raw in paths:
            path = Path(raw).expanduser()
            try:
                if path.is_dir():
                    iterator = path.rglob("*") if settings.automation.recursive_folder_import else path.glob("*")
                    for candidate in iterator:
                        try:
                            if candidate.is_file() and is_supported_image(candidate):
                                expanded.append(candidate)
                        except OSError:
                            unreadable += 1
                elif path.is_file() and is_supported_image(path):
                    expanded.append(path)
            except OSError:
                unreadable += 1
        if unreadable:
            self.status_message.emit(f"{unreadable} caminho(s) não puderam ser lidos e foram ignorados.")
        return sorted(expanded, key=lambda item: (str(item.parent).casefold(), item.name.casefold()))

    @staticmethod
    def _path_key(path: Path) -> str:
        try:
            resolved = path.resolve()
        except OSError:
            resolved = path.absolute()
        return os.path.normcase(str(resolved))

    def _add_paths(self, paths: list[Path]) -> None:
        if self._thread is not None:
            self.status_message.emit("Aguarde ou cancele o OCR antes de alterar a fila.")
            return
        if paths:
            first = Path(paths[0]).expanduser()
            try:
                if first.is_dir():
                    self.input_directory_used.emit(str(first))
                elif first.is_file():
                    self.input_directory_used.emit(str(first.parent))
            except OSError:
                pass

        added_paths: list[Path] = []
        existing = {self._path_key(path) for path in self.image_paths if path.exists()}
        for path in self._expand_paths(paths):
            key = self._path_key(path)
            if key not in existing:
                self.image_paths.append(path)
                existing.add(key)
                added_paths.append(path)
        if added_paths:
            self._refresh()
            self.files_changed.emit()
            self.status_message.emit(f"{len(added_paths)} print(s) adicionado(s) à fila.")
            settings: AppSettings = self._get_settings()
            if settings.automation.auto_start_ocr and self._thread is None:
                pending_keys = {self._path_key(path) for path in self._pending_auto_ocr}
                for path in added_paths:
                    if self._path_key(path) not in pending_keys:
                        self._pending_auto_ocr.append(path)
                        pending_keys.add(self._path_key(path))
                QTimer.singleShot(0, self._start_pending_auto_ocr)
        elif paths:
            self.status_message.emit("Nenhum print novo encontrado.")

    def _remove_selected(self) -> None:
        rows = sorted((self.file_list.row(item) for item in self.file_list.selectedItems()), reverse=True)
        if not rows:
            return
        self.file_list.clearSelection()
        for row in rows:
            del self.image_paths[row]
        self._refresh()
        self.files_changed.emit()

    def _clear(self) -> None:
        self.clear_files()

    def clear_files(self) -> None:
        self._pending_auto_ocr.clear()
        self.image_paths.clear()
        self._refresh()
        self.files_changed.emit()

    def set_image_paths(self, paths: list[Path]) -> None:
        self._pending_auto_ocr.clear()
        restored: list[Path] = []
        seen: set[str] = set()
        for raw in paths:
            path = Path(raw).expanduser()
            try:
                valid = path.is_file() and is_supported_image(path)
            except OSError:
                valid = False
            if not valid:
                continue
            key = self._path_key(path)
            if key not in seen:
                restored.append(path)
                seen.add(key)
        self.image_paths = restored
        self._refresh()

    def _start_pending_auto_ocr(self) -> None:
        if self._thread is not None or not self._pending_auto_ocr:
            return
        queued = list(self._pending_auto_ocr)
        self._pending_auto_ocr.clear()
        self._start_ocr(queued)

    def _open_selected_image(self) -> None:
        rows = sorted({self.file_list.row(item) for item in self.file_list.selectedItems()})
        if len(rows) != 1:
            if len(rows) > 1:
                self.status_message.emit("Selecione apenas um print para abrir.")
            return
        ImageViewerDialog.show_image(self, self.image_paths[rows[0]])
        self.status_message.emit(f"Print aberto: {self.image_paths[rows[0]].name}")

    def _refresh_selection_actions(self) -> None:
        selected = len(self.file_list.selectedItems())
        running = self._thread is not None
        self.btn_open.setEnabled(selected == 1 and not running)
        self.btn_remove.setEnabled(selected > 0 and not running)
        self.selection_label.setText(
            f"{selected} selecionado(s)" if selected else "Selecione um print para abrir ou remover"
        )

    def _refresh(self) -> None:
        selected_keys = {
            self._path_key(self.image_paths[self.file_list.row(item)])
            for item in self.file_list.selectedItems()
            if 0 <= self.file_list.row(item) < len(self.image_paths)
        }
        self.file_list.clear()
        for path in self.image_paths:
            item = QListWidgetItem(self._thumbnail(path), path.name)
            item.setToolTip(str(path))
            self.file_list.addItem(item)
            if self._path_key(path) in selected_keys:
                item.setSelected(True)

        has_files = bool(self.image_paths)
        running = self._thread is not None
        self.queue_stack.setCurrentIndex(1 if has_files else 0)
        self.queue_count.setText(f"{len(self.image_paths)} print(s)")
        self.drop_zone.set_input_enabled(not running)
        self.card_espelho.setEnabled(not running)
        self.card_text.setEnabled(not running)
        self.btn_add.setEnabled(not running)
        self.btn_folder.setEnabled(not running)
        self.btn_clear.setEnabled(has_files and not running)
        self.btn_run.setEnabled(running or has_files)
        self._refresh_selection_actions()
        if not running:
            if has_files:
                auto = self._get_settings().automation.auto_start_ocr
                suffix = " · OCR automático ativo" if auto else ""
                self.ocr_status.setText(f"{len(self.image_paths)} print(s) pronto(s){suffix}.")
            else:
                self.ocr_status.setText("Adicione prints para iniciar a leitura local.")

    def _thumbnail(self, path: Path) -> QIcon:
        reader = QImageReader(str(path))
        reader.setAutoTransform(True)
        source_size = reader.size()
        if not source_size.isValid():
            return QIcon()
        reader.setScaledSize(source_size.scaled(self._thumb_size, Qt.KeepAspectRatio))
        image = reader.read()
        if image.isNull():
            return QIcon()
        pixmap = QPixmap.fromImage(image)
        return QIcon(pixmap) if not pixmap.isNull() else QIcon()

    # ------------------------------------------------------------------
    # OCR lifecycle
    # ------------------------------------------------------------------

    def _start_ocr(self, image_paths: list[Path] | None = None) -> None:
        if self._thread is not None:
            return
        source_paths = self.image_paths if image_paths is None else image_paths
        targets = [path for path in source_paths if path.is_file()]
        if not targets:
            return
        target_keys = {self._path_key(path) for path in targets}
        self._pending_auto_ocr = [
            path for path in self._pending_auto_ocr if self._path_key(path) not in target_keys
        ]
        settings: AppSettings = self._get_settings()
        if not resolve_tesseract_cmd(settings.tesseract_cmd):
            self.status_message.emit("Tesseract não encontrado. Configure em Preferências ou importe o espelho.")
            MessageDialog.show_message(
                self,
                "OCR não configurado",
                "O Tesseract não foi encontrado. Configure o caminho em Preferências ou use o Espelho de Ponto, que não precisa de OCR.",
                "error",
            )
            return

        self._set_running(True)
        self._worker_warnings = []
        self.status_message.emit("Lendo prints com OCR local...")

        self._thread = QThread(self)
        self._worker = OcrWorker(settings, targets)
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
        self._worker.finished.connect(self._thread.quit)
        self._worker.failed.connect(self._thread.quit)
        self._worker.cancelled.connect(self._thread.quit)
        self._worker.finished.connect(self._worker.deleteLater)
        self._worker.failed.connect(self._worker.deleteLater)
        self._worker.cancelled.connect(self._worker.deleteLater)
        self._thread.finished.connect(self._thread.deleteLater)
        self._worker.progress.connect(self._on_progress)
        self._worker.warning.connect(self._on_warning)
        self._worker.finished.connect(self._on_finished)
        self._worker.failed.connect(self._on_failed)
        self._worker.cancelled.connect(self._on_cancelled)
        self._thread.start()

    def _run_or_cancel_ocr(self) -> None:
        if self._thread is not None:
            self._request_cancel()
            return
        self._start_ocr()

    def _request_cancel(self) -> None:
        if self._worker is None:
            return
        self._worker.cancel()
        self.btn_run.setEnabled(False)
        self.btn_run.setText("Cancelando…")
        self.ocr_status.setText("Terminando o print atual antes de cancelar…")
        self.status_message.emit("Cancelando OCR após o print atual...")

    def is_ocr_running(self) -> bool:
        return self._thread is not None

    def _on_finished(self, records: list[TimesheetRecord]) -> None:
        warnings = list(self._worker_warnings)
        self._teardown_thread()
        self._set_running(False)
        self.status_message.emit(f"OCR concluído · {len(records)} registro(s) consolidado(s).")
        if warnings:
            preview = "\n".join(warnings[:8])
            if len(warnings) > 8:
                preview += f"\n... e mais {len(warnings) - 8} aviso(s)."
            MessageDialog.show_message(
                self,
                "OCR concluído com avisos",
                "Os demais prints foram preservados. Confira:\n\n" + preview,
                "warning",
            )
        self.records_ready.emit(records)

    def _on_failed(self, message: str) -> None:
        self._teardown_thread()
        self._set_running(False)
        self.status_message.emit("Falha no OCR.")
        MessageDialog.show_message(self, "Erro no OCR", message, "error")

    def _on_cancelled(self) -> None:
        self._teardown_thread()
        self._set_running(False)
        self.status_message.emit("OCR cancelado · nenhum resultado parcial foi importado.")

    def _on_warning(self, message: str) -> None:
        self._worker_warnings.append(message)

    def _on_progress(self, message: str) -> None:
        self.ocr_status.setText(message)
        self.status_message.emit(message)

    def _teardown_thread(self) -> None:
        thread = self._thread
        self._thread = None
        self._worker = None
        if thread is not None and thread.isRunning():
            thread.quit()
            thread.wait()

    def _set_running(self, running: bool) -> None:
        self.progress.setVisible(running)
        self.drop_zone.set_input_enabled(not running)
        self.card_espelho.setEnabled(not running)
        self.card_text.setEnabled(not running)
        self.btn_add.setEnabled(not running)
        self.btn_folder.setEnabled(not running)
        self.btn_clear.setEnabled(not running and bool(self.image_paths))
        self.btn_run.setEnabled(running or bool(self.image_paths))
        self.btn_run.setText("Cancelar OCR" if running else "Ler prints")
        self._refresh_selection_actions()
        if running:
            self.ocr_title.setText("OCR em andamento")
            self.ocr_status.setText("Preparando leitura...")
        else:
            self.ocr_title.setText("Leitura OCR local")
            self._refresh()
