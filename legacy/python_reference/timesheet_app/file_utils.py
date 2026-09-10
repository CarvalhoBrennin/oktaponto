from __future__ import annotations

import os
import tempfile
from collections.abc import Callable
from pathlib import Path


def atomic_write_via_path(target: str | Path, writer: Callable[[Path], None]) -> Path:
    """Escreve ``target`` por arquivo temporário no mesmo diretório.

    O arquivo final só é substituído depois que ``writer`` termina sem erro.
    Isso evita deixar configurações, sessões ou planilhas parcialmente gravadas
    quando o processo falha durante a escrita.
    """

    target = Path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(
        prefix=f".{target.stem}.",
        suffix=f".tmp{target.suffix}",
        dir=target.parent,
    )
    os.close(fd)
    temp_path = Path(temp_name)
    try:
        writer(temp_path)
        # ``os.replace`` garante atomicidade do nome, mas sem flush uma queda
        # abrupta do sistema ainda pode deixar os bytes apenas no cache do SO.
        # Sincronizar o temporário antes da troca torna sessão/config/XLSX muito
        # mais resistentes a desligamento ou crash no pior momento.
        # Em Windows, fsync de arquivo temporário pode falhar com Bad file descriptor
        # se o handle já foi sincronizado pelo writer (ex: openpyxl fecha) — best-effort.
        try:
            with temp_path.open("rb") as handle:
                os.fsync(handle.fileno())
        except OSError:
            pass
        os.replace(temp_path, target)
        # Em POSIX, sincronizar o diretório ajuda a persistir a própria troca de
        # nome. Nem todo filesystem aceita fsync de diretório, então é best-effort.
        if os.name != "nt":
            try:
                dir_fd = os.open(target.parent, os.O_RDONLY)
                try:
                    os.fsync(dir_fd)
                finally:
                    os.close(dir_fd)
            except OSError:
                pass
    except BaseException:
        try:
            temp_path.unlink(missing_ok=True)
        except OSError:
            pass
        raise
    return target