from __future__ import annotations

import re

from .normalizer import clean_time_token

# Não capturar saldos/extras com sinal: +80:26, -0:51.
TIME_CANDIDATE_RE = re.compile(r"(?<![+\-0-9A-Za-z])([0-9OoQqDdIiLl|SsBb]{1,2})\s*[:;. ]\s*([0-9OoQqDdIiLl|SsBb]{2})(?![0-9A-Za-z])")
DATE_RE = re.compile(r"\b([0-3]?\d)[/\-.]([01]?\d)[/\-.]((?:20|19)\d{2})\b")


def parse_hhmm_token(token: str, max_hours: int = 24) -> int | None:
    token = token.strip()
    if not token or token[0] in "+-":
        return None
    cleaned = clean_time_token(token)
    match = re.fullmatch(r"(\d{1,2}):(\d{2})", cleaned)
    if not match:
        return None
    hours = int(match.group(1))
    minutes = int(match.group(2))
    if minutes >= 60:
        return None
    if hours > max_hours:
        return None
    return hours * 60 + minutes


def find_time_candidates(text: str, max_hours: int = 24) -> list[tuple[str, int]]:
    candidates: list[tuple[str, int]] = []
    for match in TIME_CANDIDATE_RE.finditer(text or ""):
        token = f"{match.group(1)}:{match.group(2)}"
        minutes = parse_hhmm_token(token, max_hours=max_hours)
        if minutes is not None:
            candidates.append((token, minutes))
    return candidates
