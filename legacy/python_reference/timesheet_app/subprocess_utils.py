"""Utilitários de subprocess específicos por plataforma."""

from __future__ import annotations

import os
import subprocess


def subprocess_no_window_kwargs() -> dict:
    """Evita flash de console ao executar processos filhos no Windows (ex.: Tesseract)."""
    if os.name != "nt":
        return {}
    kwargs: dict = {}
    if hasattr(subprocess, "CREATE_NO_WINDOW"):
        kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
    else:
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = subprocess.SW_HIDE
        kwargs["startupinfo"] = startupinfo
    return kwargs
