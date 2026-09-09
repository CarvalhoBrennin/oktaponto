from __future__ import annotations

import logging
import sys
import tempfile
from datetime import datetime
from pathlib import Path

from .settings import get_config_dir

LOG_FILENAME_GLOB = "log_*.log"
MAX_LOG_FILES = 2


def get_logs_dir() -> Path:
    # O diretório do pacote pode ser somente leitura (principalmente em builds
    # PyInstaller). Logs pertencem aos dados do usuário, não ao código-fonte.
    try:
        return get_config_dir() / "logs"
    except OSError:
        return Path(tempfile.gettempdir()) / "timesheet_banco_horas" / "logs"


class AuditFormatter(logging.Formatter):
    LEVEL_LABELS = {
        "WARNING": "WARN",
        "CRITICAL": "ERROR",
    }

    def format(self, record: logging.LogRecord) -> str:
        level = self.LEVEL_LABELS.get(record.levelname, record.levelname)
        component = getattr(record, "component", record.name)
        timestamp = datetime.fromtimestamp(record.created).strftime("%Y-%m-%d %H:%M:%S")
        message = record.getMessage()
        line = f"[{timestamp}] [{level}] [{component}] {message}"
        if record.exc_info and not record.exc_text:
            record.exc_text = self.formatException(record.exc_info)
        if record.exc_text:
            line = f"{line}\n{record.exc_text}"
        return line


def _new_log_path(logs_dir: Path) -> Path:
    """Reserva um arquivo de log sem corrida entre instâncias simultâneas."""
    base = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    suffix = 1
    while True:
        name = f"log_{base}.log" if suffix == 1 else f"log_{base}_{suffix}.log"
        candidate = logs_dir / name
        try:
            candidate.touch(exist_ok=False)
            return candidate
        except FileExistsError:
            suffix += 1


def rotate_logs(logs_dir: Path) -> Path:
    logs_dir.mkdir(parents=True, exist_ok=True)

    def safe_mtime(path: Path) -> float:
        try:
            return path.stat().st_mtime
        except OSError:
            # Outra instância pode ter removido/rotacionado o arquivo entre o
            # glob e o stat. Coloque-o no fim e siga sem falhar a inicialização.
            return float("-inf")

    existing = sorted(
        logs_dir.glob(LOG_FILENAME_GLOB),
        key=safe_mtime,
        reverse=True,
    )
    for stale in existing[MAX_LOG_FILES - 1 :]:
        try:
            stale.unlink(missing_ok=True)
        except OSError:
            # Em Windows um FileHandler de outra instância pode manter o log
            # bloqueado. Não vale impedir o novo processo por causa da rotação.
            pass

    return _new_log_path(logs_dir)


_root_handler: logging.FileHandler | None = None


def setup_audit_logging(logs_dir: Path | None = None) -> Path:
    global _root_handler

    directory = logs_dir or get_logs_dir()
    try:
        log_file = rotate_logs(directory)
    except OSError:
        if logs_dir is not None:
            raise
        fallback = Path(tempfile.gettempdir()) / "timesheet_banco_horas" / "logs"
        log_file = rotate_logs(fallback)

    root = logging.getLogger("timesheet")
    root.setLevel(logging.DEBUG)
    root.propagate = False

    if _root_handler is not None:
        root.removeHandler(_root_handler)
        _root_handler.close()

    handler = logging.FileHandler(log_file, encoding="utf-8")
    handler.setFormatter(AuditFormatter())
    root.addHandler(handler)
    _root_handler = handler

    logger = get_logger("app")
    logger.info("Sessão de log iniciada: %s", log_file.name)
    return log_file


def get_logger(component: str) -> logging.LoggerAdapter:
    base = logging.getLogger("timesheet")
    return logging.LoggerAdapter(base, {"component": component})


def install_exception_hook() -> None:
    def hook(exc_type: type[BaseException], exc_value: BaseException, exc_tb: object) -> None:
        if issubclass(exc_type, KeyboardInterrupt):
            sys.__excepthook__(exc_type, exc_value, exc_tb)
            return
        get_logger("app").error(
            "Exceção não tratada: %s",
            exc_value,
            exc_info=(exc_type, exc_value, exc_tb),
        )
        sys.__excepthook__(exc_type, exc_value, exc_tb)

    sys.excepthook = hook


def shutdown_audit_logging() -> None:
    global _root_handler

    get_logger("app").info("Aplicação encerrada")
    root = logging.getLogger("timesheet")
    if _root_handler is not None:
        root.removeHandler(_root_handler)
        _root_handler.flush()
        _root_handler.close()
        _root_handler = None
