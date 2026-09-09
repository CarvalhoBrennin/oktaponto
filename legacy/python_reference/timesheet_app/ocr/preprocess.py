from __future__ import annotations

import math
from pathlib import Path
from tempfile import NamedTemporaryFile

from PIL import Image, ImageEnhance, ImageOps, ImageFilter


SUPPORTED_IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}
TARGET_MIN_WIDTH = 1500
MAX_UPSCALE_FACTOR = 4.0
MAX_PREPROCESSED_PIXELS = 40_000_000
MAX_SOURCE_PIXELS = 60_000_000


def _bounded_upscale_factor(width: int, height: int) -> float:
    """Calcula a escala útil respeitando o orçamento final de pixels.

    O nome é mantido por compatibilidade com os testes/código existente, mas
    imagens acima do orçamento também podem receber fator menor que 1 para
    evitar manter intermediários desnecessariamente gigantes durante os filtros.
    """
    if width <= 0 or height <= 0:
        return 1.0
    pixel_budget = math.sqrt(MAX_PREPROCESSED_PIXELS / float(width * height))
    if pixel_budget < 1.0:
        return pixel_budget
    if width >= TARGET_MIN_WIDTH:
        return 1.0
    desired = TARGET_MIN_WIDTH / float(width)
    return min(desired, MAX_UPSCALE_FACTOR, pixel_budget)


def is_supported_image(path: str | Path) -> bool:
    return Path(path).suffix.lower() in SUPPORTED_IMAGE_EXTENSIONS


def prepare_for_ocr(image_path: str | Path) -> Path:
    """Prepara o print para OCR e retorna o caminho de um PNG temporário.

    O objetivo é melhorar legibilidade sem cortar partes da tela. As regras são
    conservadoras para evitar perda de informações em prints com rolagem.
    """

    source = Path(image_path)
    with Image.open(source) as img:
        source_pixels = img.width * img.height
        if img.width <= 0 or img.height <= 0 or source_pixels > MAX_SOURCE_PIXELS:
            raise Image.DecompressionBombError(
                f"Imagem grande demais para OCR seguro: {img.width}x{img.height} "
                f"({source_pixels:,} pixels; limite {MAX_SOURCE_PIXELS:,})."
            )

        img = ImageOps.exif_transpose(img)
        img = img.convert("RGB")

        # Screenshots de celular costumam ser estreitos. Aumentar a largura
        # melhora a leitura dos textos pequenos pelo Tesseract. Imagens muito
        # grandes, por outro lado, são reduzidas até o mesmo orçamento.
        scale = _bounded_upscale_factor(img.width, img.height)
        if not math.isclose(scale, 1.0):
            new_size = (max(1, int(img.width * scale)), max(1, int(img.height * scale)))
            img = img.resize(new_size, Image.Resampling.LANCZOS)

        img = ImageOps.grayscale(img)
        img = ImageEnhance.Contrast(img).enhance(1.45)
        img = ImageEnhance.Sharpness(img).enhance(1.25)
        img = img.filter(ImageFilter.SHARPEN)

        tmp = NamedTemporaryFile(delete=False, suffix=".png")
        tmp_path = Path(tmp.name)
        tmp.close()
        try:
            img.save(tmp_path, format="PNG", optimize=True)
            return tmp_path
        except BaseException:
            try:
                tmp_path.unlink(missing_ok=True)
            except OSError:
                pass
            raise
