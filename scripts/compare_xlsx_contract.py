#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import json
from pathlib import Path


def _normalize_alignment(contract: dict) -> None:
    """Normaliza diferenças irrelevantes entre openpyxl e excel_plus.

    Texto com `General` (horizontal=None) é renderizado como `left` no Excel,
    e ambos os writers serializam de forma diferente mas semanticamente igual.
    Para o contrato, tratamos `None` como `left` para células de texto.
    """
    for sheet in contract.get("sheets", []):
        for cell in sheet.get("cells", []):
            alignment = cell.get("alignment")
            if alignment is None:
                continue
            # Texto puro com General rende como left; excel_plus omite left por ser default
            if cell.get("data_type") == "s" and alignment.get("horizontal") is None:
                alignment["horizontal"] = "left"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("expected")
    parser.add_argument("actual")
    args = parser.parse_args()
    expected = json.loads(Path(args.expected).read_text(encoding="utf-8"))
    actual = json.loads(Path(args.actual).read_text(encoding="utf-8"))
    _normalize_alignment(expected)
    _normalize_alignment(actual)
    if expected == actual:
        print("XLSX semantic contract: OK")
        return 0
    a = json.dumps(expected, ensure_ascii=False, indent=2, sort_keys=True).splitlines()
    b = json.dumps(actual, ensure_ascii=False, indent=2, sort_keys=True).splitlines()
    print("\n".join(difflib.unified_diff(a, b, fromfile="expected", tofile="actual", lineterm="")))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
