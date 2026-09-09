from __future__ import annotations

import csv
import math
import os
import shutil
import subprocess
from collections import defaultdict
from pathlib import Path
from typing import Iterable

from .preprocess import prepare_for_ocr
from ..models import OcrLine, OcrResult, OcrWord
from ..subprocess_utils import subprocess_no_window_kwargs


COMMON_TESSERACT_PATHS = [
    r"C:\\Program Files\\Tesseract-OCR\\tesseract.exe",
    r"C:\\Program Files (x86)\\Tesseract-OCR\\tesseract.exe",
    "/usr/bin/tesseract",
    "/usr/local/bin/tesseract",
    "/opt/homebrew/bin/tesseract",
]


class OcrError(RuntimeError):
    pass


def normalize_tesseract_lang(lang: str = "") -> str:
    """Normaliza uma especificação ``por+eng`` para o formato aceito pelo Tesseract."""
    parts: list[str] = []
    for item in (lang or "").split("+"):
        normalized = item.strip()
        if normalized and normalized not in parts:
            parts.append(normalized)
    return "+".join(parts) or "por+eng"


def resolve_tesseract_cmd(configured_path: str = "") -> str | None:
    candidates: list[str] = []
    if configured_path.strip():
        candidates.append(str(Path(configured_path.strip().strip('"')).expanduser()))

    env_path = os.environ.get("TESSERACT_CMD", "").strip().strip('"')
    if env_path:
        candidates.append(str(Path(env_path).expanduser()))

    found = shutil.which("tesseract")
    if found:
        candidates.append(found)

    candidates.extend(COMMON_TESSERACT_PATHS)

    for candidate in candidates:
        path = Path(candidate)
        if path.exists() and path.is_file():
            return str(path)
        # shutil.which pode retornar apenas o nome quando está no PATH.
        if os.path.sep not in candidate and shutil.which(candidate):
            return candidate
    return None


def check_tesseract(configured_path: str = "", lang: str = "") -> tuple[bool, str]:
    cmd = resolve_tesseract_cmd(configured_path)
    if not cmd:
        return False, "Tesseract não encontrado. Configure o caminho ou instale o OCR."

    run_kwargs = dict(
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=10,
        **subprocess_no_window_kwargs(),
    )
    try:
        result = subprocess.run([cmd, "--version"], **run_kwargs)
    except OSError as exc:
        return False, f"Falha ao executar Tesseract: {exc}"
    except subprocess.TimeoutExpired:
        return False, "Tesseract não respondeu no tempo esperado."

    if result.returncode != 0:
        return False, result.stderr.strip() or result.stdout.strip() or "Tesseract retornou erro."
    first_line = (result.stdout or result.stderr).splitlines()[0] if (result.stdout or result.stderr) else cmd

    if not (lang or "").strip():
        return True, first_line
    normalized_lang = normalize_tesseract_lang(lang)
    requested = normalized_lang.split("+")

    try:
        lang_result = subprocess.run([cmd, "--list-langs"], **run_kwargs)
    except (OSError, subprocess.TimeoutExpired):
        # O binário já foi validado; não marque o OCR inteiro como indisponível
        # só porque a inspeção de idiomas falhou. O engine ainda reportará um
        # erro preciso se a execução real não puder carregar o idioma.
        return True, first_line + " · não foi possível validar os idiomas instalados"

    if lang_result.returncode != 0:
        return True, first_line + " · não foi possível validar os idiomas instalados"

    available = {
        line.strip()
        for line in (lang_result.stdout or "").splitlines()
        if line.strip() and not line.casefold().startswith("list of available languages")
    }
    missing = [item for item in requested if item not in available]
    if not missing:
        return True, first_line + f" · idioma(s): {'+'.join(requested)}"

    # O motor já possui fallback explícito para inglês quando uma combinação
    # contendo português falha por falta de traineddata. Reflita isso no teste.
    if "por" in requested and "eng" in available:
        return True, first_line + f" · {', '.join(missing)} indisponível(is); fallback 'eng' ativo"

    return False, "Idioma(s) OCR indisponível(is): " + ", ".join(missing)


def _run_tesseract(cmd: str, image_path: Path, lang: str, mode: str) -> str:
    # mode: "text" ou "tsv". Em ambos os casos a saída vai para stdout.
    args = [cmd, str(image_path), "stdout", "-l", lang, "--oem", "3", "--psm", "6"]
    if mode == "tsv":
        args.append("tsv")

    try:
        result = subprocess.run(
            args,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=60,
            **subprocess_no_window_kwargs(),
        )
    except subprocess.TimeoutExpired as exc:
        raise OcrError(f"O OCR excedeu 60 segundos para {image_path.name}.") from exc
    except OSError as exc:
        raise OcrError(f"Falha ao executar o Tesseract: {exc}") from exc
    if result.returncode != 0:
        raise OcrError(result.stderr.strip() or result.stdout.strip() or "Erro desconhecido no OCR.")
    return result.stdout


def _looks_like_language_error(exc: OcrError) -> bool:
    message = str(exc).casefold()
    return any(token in message for token in (
        "traineddata",
        "failed loading language",
        "failed to load language",
        "couldn't load any languages",
        "could not initialize tesseract",
    ))


def _parse_tsv(tsv_text: str) -> list[OcrWord]:
    def finite_int(raw: str | None, default: int = 0) -> int | None:
        try:
            value = float(raw) if raw not in (None, "") else float(default)
        except (TypeError, ValueError, OverflowError):
            return None
        if not math.isfinite(value) or not value.is_integer():
            return None
        return int(value)

    words: list[OcrWord] = []
    reader = csv.DictReader(tsv_text.splitlines(), delimiter="\t")
    for row in reader:
        text = (row.get("text") or "").strip()
        if not text:
            continue
        try:
            conf = float(row.get("conf") or -1)
        except (TypeError, ValueError, OverflowError):
            conf = -1.0
        if not math.isfinite(conf) or conf < 0:
            continue
        conf = min(conf, 100.0)

        left = finite_int(row.get("left"))
        top = finite_int(row.get("top"))
        width = finite_int(row.get("width"))
        height = finite_int(row.get("height"))
        block_num = finite_int(row.get("block_num"))
        par_num = finite_int(row.get("par_num"))
        line_num = finite_int(row.get("line_num"))
        word_num = finite_int(row.get("word_num"))
        numeric_fields = (left, top, width, height, block_num, par_num, line_num, word_num)
        if any(value is None for value in numeric_fields):
            continue
        assert left is not None and top is not None and width is not None and height is not None
        assert block_num is not None and par_num is not None and line_num is not None and word_num is not None
        if left < 0 or top < 0 or width <= 0 or height <= 0:
            continue

        words.append(OcrWord(
            text=text,
            confidence=conf,
            left=left,
            top=top,
            width=width,
            height=height,
            block_num=max(0, block_num),
            par_num=max(0, par_num),
            line_num=max(0, line_num),
            word_num=max(0, word_num),
        ))
    return words


def _group_lines(words: Iterable[OcrWord]) -> list[OcrLine]:
    groups: dict[tuple[int, int, int], list[OcrWord]] = defaultdict(list)
    for word in words:
        groups[(word.block_num, word.par_num, word.line_num)].append(word)

    lines: list[OcrLine] = []
    for _, line_words in groups.items():
        line_words.sort(key=lambda w: (w.left, w.top))
        left = min(w.left for w in line_words)
        top = min(w.top for w in line_words)
        right = max(w.right for w in line_words)
        bottom = max(w.bottom for w in line_words)
        text = " ".join(w.text for w in line_words).strip()
        if not text:
            continue
        lines.append(OcrLine(text=text, words=line_words, left=left, top=top, width=right - left, height=bottom - top))

    lines.sort(key=lambda line: (line.top, line.left))
    return lines


class TesseractOcrEngine:
    def __init__(self, tesseract_cmd: str = "", lang: str = "por+eng") -> None:
        resolved = resolve_tesseract_cmd(tesseract_cmd)
        if not resolved:
            raise OcrError(
                "Tesseract não encontrado. Instale o Tesseract OCR e configure o caminho em Preferências."
            )
        self.tesseract_cmd = resolved
        self.lang = normalize_tesseract_lang(lang)

    def read_image(self, image_path: str | Path, keep_debug_image: bool = False) -> OcrResult:
        original = Path(image_path)
        tmp_path = prepare_for_ocr(original)
        warnings: list[str] = []
        lang_used = self.lang

        try:
            try:
                tsv_text = _run_tesseract(self.tesseract_cmd, tmp_path, lang_used, "tsv")
            except OcrError as exc:
                # Só refaz com inglês quando o erro realmente aponta para dados
                # de idioma. Timeout/permissão/arquivo inválido devem falhar já
                # na primeira tentativa, sem dobrar o tempo de espera.
                if "por" in lang_used.split("+") and lang_used != "eng" and _looks_like_language_error(exc):
                    warnings.append(
                        "Pacote de idioma português indisponível ou com erro. OCR reexecutado com idioma 'eng'."
                    )
                    lang_used = "eng"
                    tsv_text = _run_tesseract(self.tesseract_cmd, tmp_path, lang_used, "tsv")
                else:
                    raise

            words = _parse_tsv(tsv_text)
            lines = _group_lines(words)
            text = "\n".join(line.text for line in lines)
            if not words:
                warnings.append("OCR não retornou palavras com coordenadas. Será usado parsing por texto bruto.")
                # A saída TSV já contém o texto reconhecido. Rodar uma segunda
                # passagem completa em todo print dobrava o custo sem ganho;
                # só pedimos texto bruto quando o TSV realmente não ajudou.
                text = _run_tesseract(self.tesseract_cmd, tmp_path, lang_used, "text")
            return OcrResult(text=text, words=words, lines=lines, source_file=str(original), warnings=warnings)
        finally:
            if not keep_debug_image:
                try:
                    tmp_path.unlink(missing_ok=True)
                except OSError:
                    pass
