from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
import os
from pathlib import Path
from typing import Iterable

from .models import AutomationConfig, TimesheetRecord
from .parser.banco_horas_parser import detect_missing_weekdays

MonthKey = tuple[int, int]


@dataclass(slots=True)
class ReviewReport:
    record_count: int
    included_count: int
    review_count: int
    ignored_count: int
    edited_count: int
    total_minutes: int
    months: list[MonthKey] = field(default_factory=list)
    missing_weekdays: list[date] = field(default_factory=list)
    suspicious_dates: list[date] = field(default_factory=list)

    @property
    def total_hhmm(self) -> str:
        hours, minutes = divmod(self.total_minutes, 60)
        return f"{hours}:{minutes:02d}"

    @property
    def has_attention_items(self) -> bool:
        return bool(self.review_count or self.missing_weekdays or self.suspicious_dates)


def group_records_by_month(records: Iterable[TimesheetRecord]) -> dict[MonthKey, list[TimesheetRecord]]:
    grouped: dict[MonthKey, list[TimesheetRecord]] = {}
    for record in records:
        if not record.eligible_for_excel():
            continue
        grouped.setdefault((record.data.year, record.data.month), []).append(record)
    for month_records in grouped.values():
        month_records.sort(key=lambda item: item.data)
    return dict(sorted(grouped.items()))


def _has_ocr_warning(record: TimesheetRecord) -> bool:
    if record.status == "revisar":
        return True
    if record.confidence is not None and record.confidence < 55:
        return True
    warning_tokens = ("conflito", "confira", "confiança baixa", "confianca baixa")
    return any(any(token in note.casefold() for token in warning_tokens) for note in record.notes)


def apply_include_decision(record: TimesheetRecord, include: bool) -> None:
    """Aplica uma decisão humana de incluir/ignorar mantendo status coerente."""
    had_ocr_warning = _has_ocr_warning(record)
    record.include = bool(include)
    record.manual_decision = True
    if record.status not in {"ok", "revisar", "editado", "ignorado"}:
        record.status = "editado" if record.include else "ignorado"
        return
    if record.status == "editado":
        return
    if had_ocr_warning:
        record.status = "editado" if record.include else "ignorado"
        return
    if record.include and (record.worked_minutes or 0) > 0 and record.status == "ignorado":
        record.status = "ok"
    elif not record.include and record.status == "ok":
        record.status = "ignorado"


def is_review_exception(record: TimesheetRecord) -> bool:
    if record.status not in {"ok", "revisar", "editado", "ignorado"}:
        return True
    # Uma decisão manual explícita encerra os alertas derivados do OCR antigo
    # (confiança baixa/notas de conflito), mas nunca encobre um valor impossível.
    valid_positive_minutes = record.worked_minutes_is_valid()
    if record.status == "ignorado":
        if record.include:
            return True
        # Ignorados automaticamente (ex.: 0:00) só são silenciosos quando a
        # leitura era confiável. Uma baixa confiança continua pendente até o
        # usuário decidir explicitamente ignorar.
        return False if record.manual_decision else _has_ocr_warning(record)
    if record.status == "editado":
        if not record.include:
            return False
        return not valid_positive_minutes
    if record.status == "revisar":
        return True
    # Estado ``ok`` deve ser internamente coerente; corrupção/estado legado não
    # pode desaparecer do filtro de pendências apenas por não ser exportável.
    if not record.include or not valid_positive_minutes:
        return True
    return _has_ocr_warning(record)


def analyze_records(records: Iterable[TimesheetRecord]) -> ReviewReport:
    items = list(records)
    included = [record for record in items if record.eligible_for_excel()]
    suspicious = [
        record.data
        for record in items
        if record.include
        and isinstance(record.worked_minutes, int)
        and not isinstance(record.worked_minutes, bool)
        and record.worked_minutes > 16 * 60
    ]
    return ReviewReport(
        record_count=len(items),
        included_count=len(included),
        review_count=sum(1 for record in items if is_review_exception(record)),
        ignored_count=sum(1 for record in items if not record.eligible_for_excel()),
        edited_count=sum(1 for record in items if record.status == "editado"),
        total_minutes=sum(record.worked_minutes or 0 for record in included),
        months=sorted({(record.data.year, record.data.month) for record in included}),
        missing_weekdays=detect_missing_weekdays(items),
        suspicious_dates=suspicious,
    )


def preferred_output_directory(config: AutomationConfig) -> Path:
    for candidate in (config.output_dir, config.last_output_dir):
        if candidate:
            return Path(candidate).expanduser()
    documents = Path.home() / "Documents"
    base = documents if documents.exists() else Path.home()
    return base / "Timesheets"


def next_available_path(path: str | Path) -> Path:
    """Evita sobrescrever arquivos automaticamente."""
    path = Path(path)
    if not path.exists():
        return path
    stem, suffix = path.stem, path.suffix
    counter = 2
    while True:
        candidate = path.with_name(f"{stem} ({counter}){suffix}")
        if not candidate.exists():
            return candidate
        counter += 1

def reserve_available_path(path: str | Path) -> Path:
    """Reserva atomicamente um nome de saída sem sobrescrever outro processo.

    O arquivo vazio criado aqui funciona como reserva. O gerador grava em um
    temporário e usa ``os.replace`` sobre essa reserva; em caso de erro o
    chamador deve removê-la.
    """
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    stem, suffix = path.stem, path.suffix
    counter = 1
    while True:
        candidate = path if counter == 1 else path.with_name(f"{stem} ({counter}){suffix}")
        try:
            fd = os.open(candidate, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError:
            counter += 1
            continue
        try:
            os.close(fd)
        except BaseException:
            try:
                Path(candidate).unlink(missing_ok=True)
            except OSError:
                pass
            raise
        return candidate
