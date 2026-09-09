"""Worker de OCR executado fora da thread de UI."""

from __future__ import annotations

from pathlib import Path
from threading import Event

from PySide6.QtCore import QObject, Signal
from PIL import Image

from ..audit_log import get_logger
from ..models import AppSettings, TimesheetRecord
from ..ocr.engine import OcrError, TesseractOcrEngine
from ..parser.banco_horas_parser import BancoHorasParser, consolidate_records

_log = get_logger("ocr")


class OcrWorker(QObject):
    """Lê os prints com Tesseract e devolve registros consolidados.

    Espelha a lógica de ``TimesheetDesktopApp._ocr_worker`` da UI Tkinter, mas
    comunica via sinais Qt em vez de ``queue.Queue``. Deve ser movido para um
    ``QThread`` antes de ``run`` ser chamado.
    """

    progress = Signal(str)
    warning = Signal(str)
    finished = Signal(list)  # list[TimesheetRecord]
    failed = Signal(str)
    cancelled = Signal()

    def __init__(self, settings: AppSettings, image_paths: list[Path]) -> None:
        super().__init__()
        self._settings = settings
        self._image_paths = list(image_paths)
        self._parser = BancoHorasParser()
        self._cancel_event = Event()

    def cancel(self) -> None:
        self._cancel_event.set()

    def run(self) -> None:
        total = len(self._image_paths)
        _log.info("OCR iniciado: %d imagem(ns)", total)
        try:
            engine = TesseractOcrEngine(self._settings.tesseract_cmd, self._settings.tesseract_lang)
            all_records: list[TimesheetRecord] = []
            failures = 0
            for i, path in enumerate(self._image_paths, start=1):
                if self._cancel_event.is_set():
                    _log.info("OCR cancelado pelo usuário")
                    self.cancelled.emit()
                    return
                self.progress.emit(f"Lendo {i}/{total}: {path.name}")
                try:
                    result = engine.read_image(path)
                    records = self._parser.parse_result(result)
                except (OcrError, OSError, Image.DecompressionBombError) as exc:
                    # Falhas esperadas e específicas de um arquivo não devem
                    # descartar resultados válidos de outros prints. Erros de
                    # programação ficam para o handler externo e abortam.
                    failures += 1
                    _log.warning("Falha no OCR de %s: %s", path.name, exc, exc_info=True)
                    self.warning.emit(f"{path.name}: {exc}")
                    continue
                if self._cancel_event.is_set():
                    _log.info("OCR cancelado pelo usuário")
                    self.cancelled.emit()
                    return
                if not records:
                    self.warning.emit(f"{path.name}: nenhum registro reconhecido.")
                _log.debug("  %s → %d registro(s)", path.name, len(records))
                all_records.extend(records)
            if failures == total and total:
                self.failed.emit("Nenhum dos prints pôde ser processado pelo OCR.")
                return
            if not all_records:
                self.failed.emit(
                    "O OCR terminou, mas nenhum registro de banco de horas foi reconhecido nos prints."
                )
                return
            consolidated = consolidate_records(all_records)
            _log.info("OCR concluído: %d registro(s) consolidado(s)", len(consolidated))
            self.finished.emit(consolidated)
        except OcrError as exc:
            _log.error("Falha de OCR: %s", exc)
            self.failed.emit(str(exc))
        except Exception as exc:  # noqa: BLE001 - propaga qualquer falha para a UI
            _log.error("Falha durante a leitura dos prints: %s", exc, exc_info=True)
            self.failed.emit(f"Falha durante a leitura dos prints:\n{exc}")
