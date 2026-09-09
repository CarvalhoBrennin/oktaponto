from __future__ import annotations

import re
import unicodedata
from datetime import date

from ..constants import DIAS_SEMANA_PT


_WEEKDAY_ALIASES = {
    "SEGUNDA": "Segunda-feira",
    "SEGUNDA FEIRA": "Segunda-feira",
    "TERCA": "Terça-feira",
    "TERCA FEIRA": "Terça-feira",
    "TERÇA": "Terça-feira",
    "TERÇA FEIRA": "Terça-feira",
    "QUARTA": "Quarta-feira",
    "QUARTA FEIRA": "Quarta-feira",
    "QUINTA": "Quinta-feira",
    "QUINTA FEIRA": "Quinta-feira",
    "SEXTA": "Sexta-feira",
    "SEXTA FEIRA": "Sexta-feira",
    "SABADO": "Sábado",
    "SÁBADO": "Sábado",
    "DOMINGO": "Domingo",
}


def strip_accents(text: str) -> str:
    normalized = unicodedata.normalize("NFD", text)
    return "".join(ch for ch in normalized if unicodedata.category(ch) != "Mn")


def normalize_text(text: str) -> str:
    text = strip_accents(text or "")
    text = text.upper()
    text = text.replace("—", "-").replace("–", "-")
    text = re.sub(r"[^A-Z0-9:/+\-., ]+", " ", text)
    text = re.sub(r"[\s_]+", " ", text)
    return text.strip()


def extract_weekday(text: str) -> str | None:
    normalized = normalize_text(text).replace("-", " ")
    normalized = re.sub(r"\s+", " ", normalized)
    for alias, canonical in _WEEKDAY_ALIASES.items():
        if alias in normalized:
            return canonical
    return None


def expected_weekday(d: date) -> str:
    return DIAS_SEMANA_PT[d.weekday()]


def normalize_ocr_digit_char(ch: str) -> str:
    replacements = {
        "O": "0",
        "o": "0",
        "Q": "0",
        "q": "0",
        "D": "0",
        "d": "0",
        "I": "1",
        "i": "1",
        "l": "1",
        "L": "1",
        "|": "1",
        "S": "5",
        "s": "5",
        "B": "8",
        "b": "8",
    }
    return replacements.get(ch, ch)


def clean_time_token(token: str) -> str:
    token = token.strip()
    token = token.replace(";", ":").replace(".", ":")
    token = "".join(normalize_ocr_digit_char(ch) if ch != ":" else ch for ch in token)
    token = re.sub(r"\s+", "", token)
    return token
