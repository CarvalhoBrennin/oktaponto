from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
import math
from pathlib import Path
from typing import Any

from .constants import dia_semana_pt


def _coerce_bool(value: Any, default: bool) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return default
    if isinstance(value, str):
        normalized = value.strip().casefold()
        if normalized in {"1", "true", "sim", "yes", "on"}:
            return True
        if normalized in {"0", "false", "nao", "não", "no", "off"}:
            return False
        return default
    if isinstance(value, (int, float)) and value in {0, 1}:
        return bool(value)
    return default


def _coerce_string_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value] if value else []
    if isinstance(value, (list, tuple)):
        return [str(item) for item in value if item is not None]
    return []


def _coerce_text(value: Any) -> str:
    return value if isinstance(value, str) else ""


@dataclass(slots=True)
class TimesheetRecord:
    """Registro consolidado de um dia lido dos prints do Banco de Horas."""

    data: date
    dia_semana: str
    worked_minutes: int | None
    include: bool = True
    status: str = "ok"
    source_file: str = ""
    tipo: str = ""
    pontos: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
    confidence: float | None = None
    atividade: str = ""
    manual_decision: bool = False

    @property
    def worked_hhmm(self) -> str:
        if (
            not isinstance(self.worked_minutes, int)
            or isinstance(self.worked_minutes, bool)
            or self.worked_minutes < 0
        ):
            return ""
        h, m = divmod(self.worked_minutes, 60)
        return f"{h}:{m:02d}"

    def worked_minutes_is_valid(self, *, allow_zero: bool = False) -> bool:
        value = self.worked_minutes
        if not isinstance(value, int) or isinstance(value, bool):
            return False
        minimum = 0 if allow_zero else 1
        return minimum <= value <= 24 * 60

    def eligible_for_excel(self) -> bool:
        """Indica se o registro entra na planilha final."""
        if not self.worked_minutes_is_valid():
            return False
        # A decisão explícita do usuário no checkbox é necessária, mas uma
        # pendência ainda não resolvida nunca deve atravessar a última barreira
        # de exportação. Aprovar pelo checkbox transforma a linha em ``editado``.
        return bool(self.include and self.status in {"ok", "editado"})

    def as_table_row(self) -> tuple[str, str, str, str, str, str, str, str]:
        return (
            "Sim" if self.eligible_for_excel() else "Não",
            self.data.strftime("%d/%m/%Y"),
            self.dia_semana,
            self.worked_hhmm,
            self.status,
            self.atividade,
            "; ".join(self.notes),
            Path(self.source_file).name if self.source_file else "",
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "data": self.data.isoformat(),
            "dia_semana": self.dia_semana,
            "worked_minutes": self.worked_minutes,
            "include": self.include,
            "status": self.status,
            "source_file": self.source_file,
            "tipo": self.tipo,
            "pontos": list(self.pontos),
            "notes": list(self.notes),
            "confidence": self.confidence,
            "atividade": self.atividade,
            "manual_decision": self.manual_decision,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "TimesheetRecord":
        """Reconstrói um registro persistido de forma conservadora e retrocompatível."""
        record_date = date.fromisoformat(str(data["data"]))

        worked_raw = data.get("worked_minutes")
        worked_minutes: int | None = None
        if isinstance(worked_raw, int) and not isinstance(worked_raw, bool):
            worked_minutes = worked_raw
        elif isinstance(worked_raw, float) and math.isfinite(worked_raw) and worked_raw.is_integer():
            worked_minutes = int(worked_raw)
        elif isinstance(worked_raw, str):
            normalized_minutes = worked_raw.strip()
            if normalized_minutes and normalized_minutes.lstrip("+-").isdigit():
                try:
                    worked_minutes = int(normalized_minutes)
                except (ValueError, OverflowError):
                    worked_minutes = None
        if worked_minutes is not None and worked_minutes < 0:
            worked_minutes = None

        # Versões antigas podiam não ter o campo include; nesse caso mantemos
        # o comportamento histórico. Se o campo existe mas é inválido, falhar
        # fechado evita exportação acidental.
        include = True if "include" not in data else _coerce_bool(data.get("include"), False)

        status = str(data.get("status") or "ok").strip().casefold()
        invalid_status = status not in {"ok", "revisar", "editado", "ignorado"}
        if invalid_status:
            status = "revisar"
            include = False
        if worked_raw is not None and worked_minutes is None and status == "ok":
            status = "revisar"
            include = False
        if worked_minutes is not None and worked_minutes > 24 * 60:
            status = "revisar"
            include = False

        confidence_raw = data.get("confidence")
        try:
            confidence = float(confidence_raw) if confidence_raw is not None else None
            if confidence is not None and (not math.isfinite(confidence) or not 0 <= confidence <= 100):
                confidence = None
        except (TypeError, ValueError, OverflowError):
            confidence = None

        manual_decision = _coerce_bool(data.get("manual_decision"), False)
        if (
            "manual_decision" not in data
            and status == "ignorado"
            and isinstance(worked_minutes, int)
            and worked_minutes > 0
        ):
            # Compatibilidade com sessões antigas: os parsers automáticos só
            # geravam ``ignorado`` para 0:00/ausência. Portanto um valor
            # positivo ignorado já representava uma decisão do usuário.
            manual_decision = True

        return cls(
            data=record_date,
            dia_semana=dia_semana_pt(record_date),
            worked_minutes=worked_minutes,
            include=include,
            status=status,
            source_file=_coerce_text(data.get("source_file")),
            tipo=_coerce_text(data.get("tipo")),
            pontos=_coerce_string_list(data.get("pontos")),
            notes=_coerce_string_list(data.get("notes")),
            confidence=confidence,
            atividade=_coerce_text(data.get("atividade")),
            manual_decision=manual_decision,
        )


@dataclass(slots=True)
class ProfileConfig:
    colaborador: str = ""
    cargo: str = ""
    modalidade: str = ""
    atividade_padrao: str = ""


@dataclass(slots=True)
class AutomationConfig:
    """Preferências que eliminam passos repetitivos sem esconder decisões críticas."""

    autosave_session: bool = True
    restore_session: bool = True
    focus_review_issues: bool = True
    auto_start_ocr: bool = False
    recursive_folder_import: bool = True
    open_output_folder: bool = False
    output_dir: str = ""
    last_input_dir: str = ""
    last_output_dir: str = ""


@dataclass(slots=True)
class AppSettings:
    tesseract_cmd: str = ""
    tesseract_lang: str = "por+eng"
    profile: ProfileConfig = field(default_factory=ProfileConfig)
    automation: AutomationConfig = field(default_factory=AutomationConfig)


@dataclass(slots=True)
class OcrWord:
    text: str
    confidence: float
    left: int
    top: int
    width: int
    height: int
    block_num: int = 0
    par_num: int = 0
    line_num: int = 0
    word_num: int = 0

    @property
    def right(self) -> int:
        return self.left + self.width

    @property
    def bottom(self) -> int:
        return self.top + self.height

    @property
    def center_x(self) -> float:
        return self.left + self.width / 2

    @property
    def center_y(self) -> float:
        return self.top + self.height / 2


@dataclass(slots=True)
class OcrLine:
    text: str
    words: list[OcrWord]
    left: int
    top: int
    width: int
    height: int

    @property
    def bottom(self) -> int:
        return self.top + self.height


@dataclass(slots=True)
class OcrResult:
    text: str
    words: list[OcrWord]
    lines: list[OcrLine]
    source_file: str
    warnings: list[str] = field(default_factory=list)
