"""Janela principal do HoraFolio — shell, navegação e orquestração do fluxo."""

from __future__ import annotations

from pathlib import Path
from collections.abc import Callable

from PySide6.QtCore import QEvent, QTimer, Qt
from PySide6.QtGui import QKeySequence, QShortcut
from PySide6.QtWidgets import QApplication, QFileDialog, QHBoxLayout, QMainWindow, QStackedWidget, QVBoxLayout, QWidget

from ..audit_log import get_logger
from ..automation import analyze_records
from ..models import TimesheetRecord
from ..ocr.engine import check_tesseract
from ..parser.banco_horas_parser import BancoHorasParser, consolidate_records
from ..parser.espelho_parser import parse_espelho_file
from ..session_store import clear_session, load_session, save_session
from ..settings import load_settings, save_settings
from .dialogs import MessageDialog, SettingsDialog, ShortcutDialog, TextImportDialog
from .pages.page_export import ExportPage
from .pages.page_prints import PrintsPage
from .pages.page_review import ReviewPage
from .theme import scaled
from .title_bar import TitleBar
from .widgets import NavigationRail, Toast

_log = get_logger("ui")

_STEPS = [
    ("image", "Entrada", "Prints e fontes"),
    ("check", "Revisão", "Conferir dias"),
    ("spreadsheet", "Excel", "Gerar arquivos"),
]
_PAGE_CONTEXT = ["Entrada", "Revisão", "Excel"]

_WIN_W_FRAC = 0.82
_WIN_H_FRAC = 0.86


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("HoraFolio")
        self.setWindowFlags(Qt.Window | Qt.FramelessWindowHint)

        self.settings = load_settings()
        self._parser = BancoHorasParser()

        screen = QApplication.primaryScreen()
        if screen:
            avail = screen.availableGeometry()
            init_w = int(avail.width() * _WIN_W_FRAC)
            init_h = int(avail.height() * _WIN_H_FRAC)
        else:
            init_w, init_h = 1320, 820
        self.resize(max(scaled(1040), init_w), max(scaled(650), init_h))
        self.setMinimumSize(scaled(860), scaled(560))

        shell = QWidget()
        shell.setObjectName("AppShell")
        self.setCentralWidget(shell)
        outer = QVBoxLayout(shell)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        self.title_bar = TitleBar("HoraFolio")
        self.title_bar.settings_requested.connect(self._open_settings)
        self.title_bar.shortcuts_requested.connect(lambda: ShortcutDialog.show_shortcuts(self))
        outer.addWidget(self.title_bar)

        workspace = QWidget()
        workspace_layout = QHBoxLayout(workspace)
        workspace_layout.setContentsMargins(0, 0, 0, 0)
        workspace_layout.setSpacing(0)

        self.navigation = NavigationRail(_STEPS)
        self.navigation.setAccessibleName("Navegação principal do HoraFolio")
        self.navigation.step_clicked.connect(self._on_step_clicked)
        self.navigation.new_session_requested.connect(self._new_session)
        workspace_layout.addWidget(self.navigation)

        self.stack = QStackedWidget()
        self.stack.setObjectName("ContentStack")
        self.prints_page = PrintsPage(get_settings=lambda: self.settings)
        self.review_page = ReviewPage(get_settings=lambda: self.settings)
        self.export_page = ExportPage(
            get_settings=lambda: self.settings,
            get_records=lambda: self.review_page.records(),
        )
        self.stack.addWidget(self.prints_page)
        self.stack.addWidget(self.review_page)
        self.stack.addWidget(self.export_page)
        workspace_layout.addWidget(self.stack, 1)
        outer.addWidget(workspace, 1)

        self.statusBar().showMessage("Pronto · arraste prints ou importe um espelho para começar.")

        self.prints_page.records_ready.connect(self._on_records_ready)
        self.prints_page.request_text_import.connect(self._import_text)
        self.prints_page.request_espelho_import.connect(self._import_espelho)
        self.prints_page.status_message.connect(self._status)
        self.prints_page.files_changed.connect(self._on_session_content_changed)
        self.prints_page.input_directory_used.connect(self._remember_input_dir)
        self.review_page.advance_requested.connect(lambda: self._go_to(2))
        self.review_page.status_message.connect(self._status)
        self.review_page.records_changed.connect(self._on_session_content_changed)
        self.export_page.status_message.connect(self._status)
        self.export_page.output_directory_used.connect(self._remember_output_dir)
        if hasattr(self.export_page, "back_requested"):
            self.export_page.back_requested.connect(lambda: self._go_to(1))

        self._session_timer = QTimer(self)
        self._session_timer.setSingleShot(True)
        self._session_timer.setInterval(350)
        self._session_timer.timeout.connect(self._save_session_now)

        self._install_shortcuts()
        self._refresh_ocr_status()
        if not self._restore_session():
            self._go_to(0)
        self._refresh_session_summary()
        self._update_responsive_state()

    # ------------------------------------------------------------------
    # Navigation / keyboard
    # ------------------------------------------------------------------

    def _install_shortcuts(self) -> None:
        shortcuts: list[tuple[str, Callable[[], None]]] = [
            ("Ctrl+N", self._new_session),
            ("Ctrl+,", self._open_settings),
            ("Ctrl+/", lambda: ShortcutDialog.show_shortcuts(self)),
            ("Ctrl+1", lambda: self._on_step_clicked(0)),
            ("Ctrl+2", lambda: self._on_step_clicked(1)),
            ("Ctrl+3", lambda: self._on_step_clicked(2)),
            ("Ctrl+O", self.prints_page.browse_images),
            ("Ctrl+Shift+O", self.prints_page.browse_folder),
            ("Ctrl+I", self._import_espelho),
            ("Ctrl+Shift+I", self._import_text),
            ("Ctrl+F", self._focus_context_search),
        ]
        self._shortcuts: list[QShortcut] = []
        for sequence, callback in shortcuts:
            shortcut = QShortcut(QKeySequence(sequence), self)
            shortcut.setContext(Qt.ShortcutContext.WindowShortcut)
            shortcut.activated.connect(callback)
            self._shortcuts.append(shortcut)

    def _focus_context_search(self) -> None:
        if self.stack.currentIndex() != 1 and self.review_page.records():
            self._go_to(1)
        self.review_page.focus_search()

    def _go_to(self, index: int) -> None:
        if index < 0 or index >= self.stack.count():
            return
        if index == 2:
            self.export_page.refresh()
        self.stack.setCurrentIndex(index)
        self.navigation.set_current(index)
        self.title_bar.set_context(_PAGE_CONTEXT[index])
        self._schedule_session_save()
        self._refresh_session_summary()

    def _on_step_clicked(self, index: int) -> None:
        if index > 0 and not self.review_page.records():
            self._status("Ainda não há registros. Adicione prints ou importe um espelho primeiro.")
            self._toast("Adicione uma fonte antes de avançar.", "info")
            return
        if index == 2:
            report = analyze_records(self.review_page.records())
            if report.review_count:
                self._status(f"Resolva ou ignore as {report.review_count} pendência(s) antes de gerar o Excel.")
                self._toast("A revisão ainda tem pendências.", "warning")
                self._go_to(1)
                return
            if not report.included_count:
                self._toast("Não há dias aprovados para exportar.", "warning")
                self._go_to(1)
                return
        self._go_to(index)

    def changeEvent(self, event) -> None:  # noqa: N802
        super().changeEvent(event)
        if event.type() == QEvent.Type.WindowStateChange and hasattr(self, "title_bar"):
            self.title_bar.sync_window_state()

    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        # ``resize()`` pode disparar antes de o shell terminar de ser montado.
        if not hasattr(self, "navigation"):
            return
        self._update_responsive_state()

    def _update_responsive_state(self) -> None:
        if not hasattr(self, "navigation"):
            return
        compact = self.width() < scaled(1120)
        self.navigation.set_compact(compact)
        for page in (self.prints_page, self.review_page, self.export_page):
            if hasattr(page, "set_compact_mode"):
                page.set_compact_mode(compact)

    # ------------------------------------------------------------------
    # Import / OCR integration
    # ------------------------------------------------------------------

    def _on_records_ready(self, records: list[TimesheetRecord]) -> None:
        merged = consolidate_records([*self.review_page.records(), *records])
        _log.info("OCR concluído na UI: %d registro(s), %d após consolidação", len(records), len(merged))
        self.review_page.set_records(merged, focus_issues=True)
        self._go_to(1)
        report = analyze_records(merged)
        details = []
        if report.review_count:
            details.append(f"{report.review_count} pendência(s)")
        if report.missing_weekdays:
            details.append(f"{len(report.missing_weekdays)} possível(is) dia(s) ausente(s)")
        suffix = " · " + " · ".join(details) if details else ""
        self._toast(
            f"{len(records)} registro(s) lido(s) · {len(merged)} na sessão{suffix}.",
            "warning" if details else "success",
        )
        self._refresh_session_summary()

    def _import_text(self) -> None:
        text = TextImportDialog.get_text(self)
        if not text:
            return
        parsed = self._parser.parse_text(text, source_file="texto_importado")
        if not parsed:
            _log.warning("Importação de texto: nenhum registro encontrado")
            self._toast("Nenhum registro foi reconhecido no texto.", "warning")
            return
        merged = consolidate_records([*self.review_page.records(), *parsed])
        self.review_page.set_records(merged, focus_issues=True)
        self._go_to(1)
        report = analyze_records(merged)
        self._toast(
            f"{len(parsed)} registro(s) importado(s)" +
            (f" · {report.review_count} pendência(s)." if report.review_count else "."),
            "warning" if report.review_count else "success",
        )
        _log.info("Importação de texto: %d registro(s), %d após merge", len(parsed), len(merged))

    def _import_espelho(self) -> None:
        filename, _ = QFileDialog.getOpenFileName(
            self,
            "Importar espelho de ponto",
            self.settings.automation.last_input_dir,
            "Espelho de Ponto (*.xlsx *.xlsm *.pdf);;Todos os arquivos (*.*)",
        )
        if not filename:
            return
        path = Path(filename)
        self._remember_input_dir(str(path.parent))
        try:
            parsed = parse_espelho_file(path)
        except Exception as exc:  # noqa: BLE001 - erro de arquivo deve chegar ao usuário
            _log.error("Falha ao importar espelho: %s", exc, exc_info=True)
            MessageDialog.show_message(self, "Não foi possível importar", str(exc), "error")
            return
        if not parsed:
            self._toast("Nenhum registro reconhecido nesse espelho.", "warning")
            return

        merged = consolidate_records([*self.review_page.records(), *parsed])
        self.review_page.set_records(merged, focus_issues=True)
        self._go_to(1)
        report = analyze_records(merged)
        details = []
        if report.review_count:
            details.append(f"{report.review_count} para revisar")
        if report.missing_weekdays:
            details.append(f"{len(report.missing_weekdays)} possível(is) ausência(s)")
        message = f"{len(parsed)} registro(s) importado(s) de {path.name}"
        if details:
            message += " · " + " · ".join(details)
        self._toast(message + ".", "warning" if details else "success")
        _log.info("Espelho importado: %s · %d registro(s)", path, len(parsed))

    # ------------------------------------------------------------------
    # Settings / persistence
    # ------------------------------------------------------------------

    def _open_settings(self) -> None:
        updated = SettingsDialog.edit_settings(self, self.settings)
        if not updated:
            return
        try:
            save_settings(updated)
        except OSError as exc:
            _log.error("Falha ao salvar preferências: %s", exc, exc_info=True)
            MessageDialog.show_message(
                self,
                "Não foi possível salvar",
                "As preferências não foram alteradas porque o arquivo de configuração não pôde ser gravado.\n\n" + str(exc),
                "error",
            )
            return
        self.settings = updated
        self._refresh_ocr_status()
        self.prints_page.refresh_from_settings()
        self.review_page.refresh_from_settings()
        if self.stack.currentIndex() == 2:
            self.export_page.refresh()
        self._toast("Preferências salvas.", "success")

    def _remember_input_dir(self, directory: str) -> None:
        if directory and self.settings.automation.last_input_dir != directory:
            previous = self.settings.automation.last_input_dir
            self.settings.automation.last_input_dir = directory
            try:
                save_settings(self.settings)
            except OSError as exc:
                self.settings.automation.last_input_dir = previous
                _log.warning("Não foi possível lembrar a pasta de entrada: %s", exc)

    def _remember_output_dir(self, directory: str) -> None:
        if directory and self.settings.automation.last_output_dir != directory:
            previous = self.settings.automation.last_output_dir
            self.settings.automation.last_output_dir = directory
            try:
                save_settings(self.settings)
            except OSError as exc:
                self.settings.automation.last_output_dir = previous
                _log.warning("Não foi possível lembrar a pasta de saída: %s", exc)

    def _on_session_content_changed(self) -> None:
        self._schedule_session_save()
        self._refresh_session_summary()

    def _schedule_session_save(self) -> None:
        if hasattr(self, "_session_timer") and self.settings.automation.autosave_session:
            self._session_timer.start()

    def _save_session_now(self) -> None:
        if not self.settings.automation.autosave_session:
            return
        records = self.review_page.records()
        images = self.prints_page.image_paths
        try:
            if not records and not images:
                clear_session()
                return
            save_session(records, images, self.stack.currentIndex())
        except OSError as exc:
            _log.warning("Não foi possível salvar a sessão automaticamente: %s", exc)

    def _restore_session(self) -> bool:
        if not (self.settings.automation.autosave_session and self.settings.automation.restore_session):
            return False
        snapshot = load_session()
        if snapshot is None or snapshot.is_empty:
            return False
        valid_images = [path for path in snapshot.image_paths if path.is_file()]
        if not snapshot.records and not valid_images:
            try:
                clear_session()
            except OSError as exc:
                _log.warning("Não foi possível remover sessão obsoleta: %s", exc)
            return False
        restored_records = consolidate_records(snapshot.records)
        self.prints_page.set_image_paths(valid_images)
        self.review_page.set_records(restored_records, focus_issues=True)
        step = snapshot.current_step if restored_records else 0
        if restored_records and step == 2:
            report = analyze_records(restored_records)
            if report.review_count or not report.included_count:
                step = 1
        self._go_to(step)
        parts = []
        if restored_records:
            parts.append(f"{len(restored_records)} registro(s)")
        if valid_images:
            parts.append(f"{len(valid_images)} print(s)")
        self._toast("Sessão recuperada · " + " · ".join(parts) + ".", "info")
        _log.info("Sessão restaurada: %d registros, %d imagens", len(restored_records), len(valid_images))
        return True

    def _new_session(self) -> None:
        if self.prints_page.is_ocr_running():
            MessageDialog.show_message(
                self,
                "OCR em andamento",
                "Cancele ou conclua a leitura antes de iniciar um novo mês.",
                "warning",
            )
            return
        has_content = bool(self.review_page.records() or self.prints_page.image_paths)
        if has_content and not MessageDialog.ask(
            self,
            "Começar novo mês",
            "Limpar os registros e prints desta sessão? Os arquivos Excel já gerados não serão apagados.",
            "Começar novo mês",
            "Cancelar",
            "warning",
        ):
            return
        if hasattr(self, "_session_timer"):
            self._session_timer.stop()
        try:
            clear_session()
        except OSError as exc:
            _log.error("Não foi possível limpar a sessão: %s", exc, exc_info=True)
            MessageDialog.show_message(
                self,
                "Não foi possível iniciar uma nova sessão",
                "A sessão atual foi mantida porque o arquivo de recuperação não pôde ser removido.\n\n" + str(exc),
                "error",
            )
            return
        self.prints_page.clear_files()
        self.review_page.set_records([])
        self._go_to(0)
        self._toast("Nova sessão iniciada.", "success")
        _log.info("Sessão limpa pelo usuário")

    # ------------------------------------------------------------------
    # Status / lifecycle
    # ------------------------------------------------------------------

    def _refresh_session_summary(self) -> None:
        records = self.review_page.records()
        report = analyze_records(records)
        self.navigation.set_summary(
            prints=len(self.prints_page.image_paths),
            records=report.record_count,
            issues=report.review_count,
            hours=report.total_hhmm,
        )

    def _refresh_ocr_status(self) -> None:
        ok, message = check_tesseract(self.settings.tesseract_cmd, self.settings.tesseract_lang)
        self.navigation.set_ocr_state(ok, "OCR disponível" if ok else "OCR indisponível", message)

    def _status(self, message: str) -> None:
        self.statusBar().showMessage(message)

    def _toast(self, message: str, kind: str = "info") -> None:
        Toast(self, message, kind).show_toast()

    def closeEvent(self, event) -> None:  # noqa: N802
        if self.prints_page.is_ocr_running():
            MessageDialog.show_message(
                self,
                "OCR em andamento",
                "Cancele ou conclua o OCR antes de fechar o aplicativo.",
                "warning",
            )
            event.ignore()
            return
        if self.settings.automation.autosave_session:
            self._session_timer.stop()
            self._save_session_now()
        super().closeEvent(event)
