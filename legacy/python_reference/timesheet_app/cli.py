from __future__ import annotations

import argparse
from pathlib import Path
import sys

from PIL import Image

from .audit_log import get_logger, install_exception_hook, setup_audit_logging, shutdown_audit_logging
from .excel.generator import generate_timesheet_batch, generate_timesheet_xlsx
from .models import ProfileConfig
from .ocr.engine import OcrError, TesseractOcrEngine
from .parser.banco_horas_parser import BancoHorasParser, consolidate_records, detect_missing_weekdays
from .parser.espelho_parser import parse_espelho_file


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Gerar timesheet Excel a partir de prints do Banco de Horas.")
    parser.add_argument("--images", nargs="+", help="Caminhos das imagens/prints.")
    parser.add_argument("--ocr-text", help="Arquivo de texto OCR/manual para parsing sem imagens.")
    parser.add_argument("--espelho", help="Espelho de Ponto (.xlsx/.xlsm/.pdf) para pular os prints/OCR.")
    output = parser.add_mutually_exclusive_group(required=True)
    output.add_argument("--output", help="Arquivo .xlsx de saída (um único mês).")
    output.add_argument("--output-dir", help="Pasta de saída; gera automaticamente um arquivo por mês.")
    parser.add_argument("--tesseract-cmd", default="", help="Caminho do executável Tesseract.")
    parser.add_argument("--tesseract-lang", default="por+eng", help="Idiomas do Tesseract. Padrão: por+eng.")
    parser.add_argument("--colaborador", default="Brenno C. Torquato")
    parser.add_argument("--cargo", default="Desenvolvedor Jr")
    parser.add_argument("--modalidade", default="Presencial")
    parser.add_argument("--atividade-padrao", default="", help="Texto padrão da coluna Atividades / Entregas.")
    return parser


def main(argv: list[str] | None = None) -> int:
    setup_audit_logging()
    install_exception_hook()
    logger = get_logger("cli")
    logger.info("CLI iniciada")

    try:
        args = build_parser().parse_args(argv)
        parser = BancoHorasParser()
        records = []

        image_failures = 0
        if args.images:
            logger.info("Processando %d imagem(ns) via OCR", len(args.images))
            engine = TesseractOcrEngine(args.tesseract_cmd, args.tesseract_lang)
            for image in args.images:
                image_path = Path(image).expanduser()
                logger.debug("OCR da imagem: %s", image_path)
                try:
                    result = engine.read_image(image_path)
                except (OcrError, OSError, Image.DecompressionBombError) as exc:
                    image_failures += 1
                    logger.warning("Falha no OCR de %s: %s", image_path, exc, exc_info=True)
                    print(f"Aviso: {image_path}: {exc}", file=sys.stderr)
                    continue
                parsed = parser.parse_result(result)
                records.extend(parsed)
                for warning in result.warnings:
                    print(f"Aviso OCR ({image_path.name}): {warning}", file=sys.stderr)
                if not parsed:
                    print(f"Aviso: nenhum registro reconhecido em {image_path}.", file=sys.stderr)
                logger.debug("Registros extraídos de %s: %d", image_path, len(parsed))

        if args.ocr_text:
            text_path = Path(args.ocr_text).expanduser()
            logger.info("Importando texto OCR: %s", text_path)
            records.extend(parser.parse_text(text_path.read_text(encoding="utf-8"), source_file=str(text_path)))

        if args.espelho:
            espelho_path = Path(args.espelho).expanduser()
            logger.info("Importando espelho de ponto: %s", espelho_path)
            parsed = parse_espelho_file(espelho_path)
            logger.debug("Registros extraídos de %s: %d", espelho_path, len(parsed))
            records.extend(parsed)

        if not records:
            logger.warning("Nenhum registro encontrado na execução da CLI")
            had_input = bool(args.images or args.ocr_text or args.espelho)
            if had_input:
                if image_failures:
                    print("Nenhum registro encontrado; um ou mais prints falharam no OCR.", file=sys.stderr)
                else:
                    print("Nenhum registro foi reconhecido nas entradas informadas.", file=sys.stderr)
                return 1
            print("Nenhum registro encontrado. Informe --images, --ocr-text ou --espelho.", file=sys.stderr)
            return 2

        consolidated = consolidate_records(records)
        missing = detect_missing_weekdays(consolidated)
        if missing:
            logger.warning(
                "Possíveis dias úteis ausentes: %s",
                ", ".join(d.strftime("%d/%m/%Y") for d in missing),
            )
            print("Aviso: possíveis dias úteis ausentes:", ", ".join(d.strftime("%d/%m/%Y") for d in missing), file=sys.stderr)

        profile = ProfileConfig(
            colaborador=args.colaborador,
            cargo=args.cargo,
            modalidade=args.modalidade,
            atividade_padrao=args.atividade_padrao,
        )
        if args.output_dir:
            results = generate_timesheet_batch(consolidated, args.output_dir, profile=profile)
            for result in results:
                print(f"Arquivo gerado: {result.output_path} | dias: {result.included_days} | total: {result.total_hhmm}")
            logger.info("Exportação em lote via CLI concluída: %d arquivo(s)", len(results))
        else:
            result = generate_timesheet_xlsx(consolidated, args.output, profile=profile)
            logger.info(
                "Excel gerado via CLI | arquivo=%s | dias_incluidos=%d | total=%s",
                result.output_path,
                result.included_days,
                result.total_hhmm,
            )
            print(f"Arquivo gerado: {result.output_path}")
            print(f"Dias incluídos: {result.included_days}")
            print(f"Total: {result.total_hhmm}")
        return 0
    except (OcrError, OSError, UnicodeError, ValueError, ImportError) as exc:
        logger.error("Falha esperada na execução da CLI: %s", exc, exc_info=True)
        print(f"Erro: {exc}", file=sys.stderr)
        return 1
    except Exception:
        logger.error("Falha na execução da CLI", exc_info=True)
        raise
    finally:
        shutdown_audit_logging()


if __name__ == "__main__":
    raise SystemExit(main())
