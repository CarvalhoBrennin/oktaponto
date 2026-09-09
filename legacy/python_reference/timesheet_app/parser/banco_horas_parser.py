from __future__ import annotations

from dataclasses import replace
from datetime import date
import math
from pathlib import Path
from typing import Iterable

from ..models import OcrLine, OcrResult, OcrWord, TimesheetRecord
from .normalizer import expected_weekday, extract_weekday, normalize_text
from .timeparse import DATE_RE, find_time_candidates, parse_hhmm_token


class BancoHorasParser:
    """Parser específico para prints do app Banco de Horas.

    O parser usa duas estratégias:
    1. coordenadas do TSV do Tesseract para pegar o horário abaixo do rótulo
       "Trabalhou";
    2. fallback por texto bruto quando as coordenadas não estão disponíveis.
    """

    def parse_result(self, result: OcrResult) -> list[TimesheetRecord]:
        if result.lines:
            records = self._parse_lines(result.lines, result.source_file)
        else:
            records = []
        if not records:
            records = self.parse_text(result.text, result.source_file)

        for record in records:
            if result.warnings:
                record.notes.extend(result.warnings)
        return records

    def parse_text(self, text: str, source_file: str = "") -> list[TimesheetRecord]:
        lines = [line.strip() for line in (text or "").splitlines() if line.strip()]
        synthetic_lines: list[OcrLine] = []
        y = 0
        for line in lines:
            synthetic_lines.append(OcrLine(text=line, words=[], left=0, top=y, width=0, height=18))
            y += 24
        return self._parse_lines(synthetic_lines, source_file)

    def _parse_lines(self, lines: list[OcrLine], source_file: str) -> list[TimesheetRecord]:
        date_line_indexes: list[int] = []
        for i, line in enumerate(lines):
            if DATE_RE.search(line.text):
                date_line_indexes.append(i)

        records: list[TimesheetRecord] = []
        for pos, start_index in enumerate(date_line_indexes):
            end_index = date_line_indexes[pos + 1] if pos + 1 < len(date_line_indexes) else len(lines)
            block = lines[start_index:end_index]
            if not block:
                continue
            record = self._parse_block(block, source_file)
            if record:
                records.append(record)
        return records

    def _parse_block(self, block: list[OcrLine], source_file: str) -> TimesheetRecord | None:
        header_text = block[0].text
        date_match = DATE_RE.search(header_text)
        if not date_match:
            # Às vezes o OCR quebra a data no segundo item do bloco.
            combined_header = " ".join(line.text for line in block[:2])
            date_match = DATE_RE.search(combined_header)
            header_text = combined_header
        if not date_match:
            return None

        day = int(date_match.group(1))
        month = int(date_match.group(2))
        year = int(date_match.group(3))
        try:
            record_date = date(year, month, day)
        except ValueError:
            return None

        weekday = extract_weekday(header_text) or expected_weekday(record_date)
        notes: list[str] = []
        expected = expected_weekday(record_date)
        if weekday != expected:
            notes.append(f"Dia da semana ajustado: OCR='{weekday}', esperado='{expected}'.")
            weekday = expected

        block_text = "\n".join(line.text for line in block)
        normalized_block = normalize_text(block_text)
        tipo = self._detect_tipo(normalized_block)
        pontos = self._extract_pontos(block_text)

        worked_minutes, confidence, extraction_note = self._extract_worked_minutes(block)
        if extraction_note:
            notes.append(extraction_note)

        status = "ok"
        include = True
        if worked_minutes is None:
            status = "revisar"
            include = False
            notes.append("Não foi possível localizar o valor de 'Trabalhou'.")
        elif worked_minutes > 24 * 60:
            status = "revisar"
            include = False
            notes.append("Valor de 'Trabalhou' acima de 24:00; confira manualmente.")
        elif worked_minutes <= 0:
            include = False
            status = "ignorado"
            if "FOLGA" in normalized_block:
                notes.append("Folga com 0:00 ignorada.")
            elif "FERIADO" in normalized_block:
                notes.append("Feriado com 0:00 ignorado.")
            elif "NAO REGISTROU" in normalized_block or "NAO REGISTR" in normalized_block:
                notes.append("Dia sem saída/sem horas ignorado.")
            else:
                notes.append("Registro 0:00 ignorado.")
        return TimesheetRecord(
            data=record_date,
            dia_semana=weekday,
            worked_minutes=worked_minutes,
            include=include,
            status=status,
            source_file=source_file,
            tipo=tipo,
            pontos=pontos,
            notes=notes,
            confidence=confidence,
        )

    @staticmethod
    def _detect_tipo(normalized_block: str) -> str:
        if "FOLGA" in normalized_block:
            return "Folga"
        if "FERIADO" in normalized_block:
            return "Feriado"
        if "EXPEDIENTE" in normalized_block and "AJUSTE APROVADO" in normalized_block:
            return "Expediente (ajuste aprovado)"
        if "EXPEDIENTE" in normalized_block:
            return "Expediente"
        return ""

    @staticmethod
    def _extract_pontos(block_text: str) -> list[str]:
        lines = block_text.splitlines()
        before_worked: list[str] = []
        for line in lines:
            if "TRABALH" in normalize_text(line):
                break
            before_worked.append(line)
        points_text = DATE_RE.sub("", "\n".join(before_worked))
        all_times = [token for token, _ in find_time_candidates(points_text, max_hours=23)]
        # Pontos pertencem à área anterior ao rótulo "Trabalhou". Limitar a
        # busca evita incluir o total trabalhado/saldos quando faltam batidas.
        return all_times[:4]

    def _extract_worked_minutes(self, block: list[OcrLine]) -> tuple[int | None, float | None, str]:
        via_coordinates = self._extract_worked_by_coordinates(block)
        if via_coordinates[0] is not None:
            return via_coordinates
        via_text = self._extract_worked_by_text(block)
        return via_text

    def _extract_worked_by_coordinates(self, block: list[OcrLine]) -> tuple[int | None, float | None, str]:
        words: list[OcrWord] = [word for line in block for word in line.words]
        if not words:
            return None, None, ""

        labels = [word for word in words if "TRABALH" in normalize_text(word.text)]
        if not labels:
            return None, None, ""

        candidates: list[tuple[float, int, OcrWord]] = []
        for label in labels:
            for word in words:
                minutes = parse_hhmm_token(word.text, max_hours=24)
                if minutes is None:
                    continue
                if word.center_y <= label.center_y:
                    continue
                vertical_distance = word.center_y - label.center_y
                if vertical_distance > max(260, label.height * 8):
                    continue
                horizontal_distance = abs(word.center_x - label.center_x)
                if horizontal_distance > max(260, label.width * 2.8):
                    continue
                score = vertical_distance * 2.0 + horizontal_distance * 0.8
                candidates.append((score, minutes, word))

        if candidates:
            candidates.sort(key=lambda item: item[0])
            _, minutes, word = candidates[0]
            confidence = word.confidence if word.confidence >= 0 else None
            note = "" if confidence is None or confidence >= 55 else f"Confiança baixa no OCR do horário ({confidence:.0f})."
            return minutes, confidence, note
        return None, None, ""

    @staticmethod
    def _extract_worked_by_text(block: list[OcrLine]) -> tuple[int | None, float | None, str]:
        block_lines = [line.text for line in block]
        for i, line in enumerate(block_lines):
            if "TRABALH" not in normalize_text(line):
                continue
            search_area = " ".join(block_lines[i : min(i + 5, len(block_lines))])
            candidates = find_time_candidates(search_area, max_hours=24)
            if candidates:
                # Em layouts com "Trabalhou Falta Saldo" e a linha seguinte
                # "7:09 -0:51 +80:26", o primeiro horário sem sinal é o campo correto.
                return candidates[0][1], None, "Extraído por texto bruto; confira na tabela."

        # Fallback final: se houver exatamente um horário plausível no bloco
        # depois de remover pontos, usar apenas quando não parecer saldo.
        fallback_text = DATE_RE.sub("", "\n".join(block_lines))
        all_candidates = find_time_candidates(fallback_text, max_hours=24)
        if len(all_candidates) == 1:
            return all_candidates[0][1], None, "Extraído por fallback geral; confira na tabela."
        return None, None, ""


def consolidate_records(records: Iterable[TimesheetRecord]) -> list[TimesheetRecord]:
    """Consolida registros por data de forma determinística e sem mutar a entrada.

    Decisões humanas continuam usando a ordem recebida (a última decisão manual
    vence). Fontes automáticas, por outro lado, não podem mudar de resultado só
    porque foram importadas em outra ordem: qualquer valor conflitante mantém a
    data em revisão até uma decisão explícita.
    """

    warning_tokens = ("conflito", "confira", "confiança baixa", "confianca baixa")
    structured_suffixes = {".xlsx", ".xlsm", ".pdf"}

    def clone(record: TimesheetRecord) -> TimesheetRecord:
        return replace(record, pontos=list(record.pontos), notes=list(record.notes))

    def append_unique(notes: list[str], note: str) -> None:
        if note and note not in notes:
            notes.append(note)

    def is_manual(record: TimesheetRecord) -> bool:
        # Além de linhas explicitamente editadas/manuais, um registro positivo
        # marcado como ignorado representa uma decisão humana no checkbox e
        # não deve ser reativado por uma importação posterior.
        return (
            record.manual_decision
            or record.status == "editado"
            or record.source_file == "manual"
            or (
                # Compatibilidade com sessões gravadas antes do campo
                # ``manual_decision``: um valor positivo ignorado só podia
                # surgir de uma ação humana no fluxo antigo.
                record.status == "ignorado"
                and isinstance(record.worked_minutes, int)
                and not isinstance(record.worked_minutes, bool)
                and record.worked_minutes > 0
            )
        )

    def note_is_warning(note: str) -> bool:
        folded = note.casefold()
        return any(token in folded for token in warning_tokens)

    def note_is_conflict(note: str) -> bool:
        return "conflito" in note.casefold()

    def automatic_quality(record: TimesheetRecord) -> tuple[object, ...]:
        status_rank = {"ok": 3, "revisar": 2, "ignorado": 1, "editado": 0}.get(record.status, 0)
        clean = int(not any(note_is_warning(note) for note in record.notes))
        structured = int(Path(record.source_file).suffix.casefold() in structured_suffixes)
        raw_confidence = record.confidence
        confidence = (
            float(raw_confidence)
            if isinstance(raw_confidence, (int, float))
            and not isinstance(raw_confidence, bool)
            and math.isfinite(float(raw_confidence))
            else -1.0
        )
        # Os campos textuais finais eliminam empates dependentes da ordem em
        # duplicatas automáticas com a mesma qualidade/fonte.
        return (
            status_rank, clean, structured, confidence,
            str(record.source_file).casefold(),
            str(record.atividade).casefold(),
            str(record.tipo).casefold(),
            tuple(str(item) for item in record.pontos),
            tuple(str(item) for item in record.notes),
        )

    def minute_score(record: TimesheetRecord) -> int:
        value = record.worked_minutes
        if isinstance(value, int) and not isinstance(value, bool):
            return value
        return -1

    def same_worked_value(items: list[TimesheetRecord]) -> bool:
        first = items[0].worked_minutes
        return all(item.worked_minutes == first for item in items[1:])

    def merge_metadata(
        preferred: TimesheetRecord,
        other: TimesheetRecord,
        *,
        skip_warning_notes: bool = False,
    ) -> None:
        # Uma atividade vazia em uma decisão manual é significativa: ela
        # significa "usar o padrão do perfil" e não deve ser repopulada.
        if not preferred.atividade and other.atividade and not is_manual(preferred):
            preferred.atividade = other.atividade
        if not preferred.tipo and other.tipo:
            preferred.tipo = other.tipo
        if not preferred.pontos and other.pontos:
            preferred.pontos = list(other.pontos)
        for note in other.notes:
            if skip_warning_notes and note_is_warning(note):
                continue
            append_unique(preferred.notes, note)
        if other.source_file and other.source_file != preferred.source_file:
            append_unique(preferred.notes, f"Também encontrado em {Path(other.source_file).name}.")

    indexed_by_date: dict[date, list[tuple[int, TimesheetRecord]]] = {}
    for index, original in enumerate(records):
        indexed_by_date.setdefault(original.data, []).append((index, clone(original)))

    consolidated: list[TimesheetRecord] = []
    for record_date in sorted(indexed_by_date):
        indexed = indexed_by_date[record_date]
        items = [record for _, record in indexed]
        if len(items) == 1:
            consolidated.append(items[0])
            continue

        manual_items = [(index, record) for index, record in indexed if is_manual(record)]
        if manual_items:
            # Ordem é semântica apenas para ações humanas: a última vence.
            _, preferred = max(manual_items, key=lambda pair: pair[0])
            has_conflict = not same_worked_value(items)
            others = [record for record in items if record is not preferred]
            others.sort(key=automatic_quality, reverse=True)
            for other in others:
                merge_metadata(preferred, other)
            if has_conflict:
                preferred.status = "editado"
                values = sorted({item.worked_hhmm or "vazio" for item in items})
                append_unique(
                    preferred.notes,
                    "Conflito entre fontes para a mesma data: "
                    + " x ".join(values)
                    + ". Decisão manual mantida.",
                )
            consolidated.append(preferred)
            continue

        if same_worked_value(items):
            # Sem decisão humana, a melhor fonte deve ser escolhida por
            # qualidade, nunca pela ordem de importação.
            preferred = max(items, key=automatic_quality)
            chosen_is_clean_ok = (
                preferred.status == "ok"
                and not any(note_is_warning(note) for note in preferred.notes)
            )
            unresolved_conflict = any(
                note_is_conflict(note)
                for record in items
                for note in record.notes
            )
            others = [record for record in items if record is not preferred]
            others.sort(key=automatic_quality, reverse=True)
            for other in others:
                merge_metadata(
                    preferred,
                    other,
                    # Uma fonte OK/limpa confirmando o mesmo valor resolve os
                    # alertas automáticos da leitura pior, sem apagar notas de
                    # negócio não relacionadas a confiança/conflito.
                    skip_warning_notes=chosen_is_clean_ok and not unresolved_conflict,
                )
            if unresolved_conflict:
                # Um registro já consolidado pode carregar evidência de um
                # valor divergente que não está mais presente na lista atual.
                # Uma nova fonte que apenas repete o candidato escolhido não
                # é suficiente para apagar esse conflito histórico.
                preferred.status = "revisar"
                preferred.include = False
            consolidated.append(preferred)
            continue

        # Conflitos exclusivamente automáticos nunca são "resolvidos" pela
        # ordem, nem por maioria acidental. Mantemos o maior valor apenas como
        # candidato visível e exigimos decisão humana antes de exportar.
        highest = max(minute_score(record) for record in items)
        candidates = [record for record in items if minute_score(record) == highest]
        preferred = max(candidates, key=automatic_quality)
        preferred.status = "revisar"
        preferred.include = False
        others = [record for record in items if record is not preferred]
        others.sort(key=automatic_quality, reverse=True)
        for other in others:
            merge_metadata(preferred, other)
        values = sorted({item.worked_hhmm or "vazio" for item in items})
        append_unique(
            preferred.notes,
            "Conflito entre fontes para a mesma data: "
            + " x ".join(values)
            + ". Valor maior mantido provisoriamente; revise antes de incluir.",
        )
        consolidated.append(preferred)

    return consolidated

def detect_missing_weekdays(records: Iterable[TimesheetRecord]) -> list[date]:
    """Detecta lacunas úteis dentro de cada mês.

    Qualquer data reconhecida conta como presente, inclusive feriado, folga ou
    registro em revisão. Assim, o mesmo dia não vira simultaneamente "pendência"
    e "dia ausente" e não surgem falsos alertas entre meses diferentes.
    """
    dates = sorted({record.data for record in records})
    grouped: dict[tuple[int, int], list[date]] = {}
    for item in dates:
        grouped.setdefault((item.year, item.month), []).append(item)

    missing: list[date] = []
    for month_dates in grouped.values():
        if len(month_dates) < 2:
            continue
        present = set(month_dates)
        current = month_dates[0]
        end = month_dates[-1]
        while current <= end:
            if current.weekday() < 5 and current not in present:
                missing.append(current)
            current = date.fromordinal(current.toordinal() + 1)
    return sorted(missing)
