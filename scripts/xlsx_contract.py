#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import date, datetime, time, timedelta
from pathlib import Path
from typing import Any

from openpyxl import load_workbook
from openpyxl.cell.cell import MergedCell


def _round_number(value: Any) -> Any:
    if isinstance(value, float):
        return round(value, 6)
    return value


def color(value, *, default_black: bool = False) -> str | None:
    """Normalize library-specific OOXML color encodings to visual semantics."""
    if value is None:
        return "000000" if default_black else None
    kind = getattr(value, "type", None)
    if kind == "rgb" and value.rgb:
        return str(value.rgb)[-6:].upper()
    if kind == "theme":
        # Theme 1 is the default dark text color in the standard workbook theme.
        if value.theme == 1 and (value.tint in (None, 0, 0.0)):
            return "000000"
        return f"theme:{value.theme}:tint:{_round_number(value.tint or 0)}"
    if kind == "indexed":
        return f"indexed:{value.indexed}"
    if kind == "auto" or getattr(value, "auto", False):
        return "000000" if default_black else "auto"
    return "000000" if default_black else None


def side(value) -> dict[str, Any] | None:
    if value is None or value.style is None:
        return None
    return {"style": value.style, "color": color(value.color)}


def cell_value(value: Any) -> Any:
    if isinstance(value, datetime):
        return {"kind": "datetime", "value": value.isoformat()}
    if isinstance(value, date):
        return {"kind": "date", "value": value.isoformat()}
    if isinstance(value, time):
        return {"kind": "time", "value": value.isoformat()}
    if isinstance(value, timedelta):
        return {"kind": "duration_seconds", "value": _round_number(value.total_seconds())}
    if isinstance(value, float):
        return _round_number(value)
    return value


def _has_meaningful_blank_style(c) -> bool:
    """Keep blank cells only when their layout is semantically visible.

    White separator fills and default style records may be serialized very
    differently by openpyxl and excel_plus, so they are intentionally ignored.
    Dark total-row fills and borders are retained.
    """
    fill = None
    if c.fill.fill_type == "solid":
        fill = color(c.fill.fgColor)
    borders = [c.border.left, c.border.right, c.border.top, c.border.bottom]
    has_border = any(side(item) is not None for item in borders)
    return has_border or (fill not in (None, "FFFFFF", "000000"))


def contract(path: Path) -> dict[str, Any]:
    wb = load_workbook(path, data_only=False)
    try:
        sheets = []
        for ws in wb.worksheets:
            cells = []
            for row in ws.iter_rows():
                for c in row:
                    if isinstance(c, MergedCell):
                        continue
                    if c.value is None:
                        if not c.has_style or not _has_meaningful_blank_style(c):
                            continue
                    fill_type = c.fill.fill_type
                    fill_fg = color(c.fill.fgColor) if fill_type == "solid" else None
                    is_blank = c.value is None
                    cells.append(
                        {
                            "coordinate": c.coordinate,
                            "value": cell_value(c.value),
                            "data_type": c.data_type,
                            "number_format": c.number_format,
                            "font": None
                            if is_blank
                            else {
                                "name": c.font.name or "Calibri",
                                "size": _round_number(c.font.sz if c.font.sz is not None else 11),
                                "bold": bool(c.font.bold),
                                "italic": bool(c.font.italic),
                                "color": color(c.font.color, default_black=True),
                            },
                            "fill": {
                                "type": fill_type,
                                "fg": fill_fg,
                            },
                            "alignment": None
                            if is_blank
                            else {
                                "horizontal": c.alignment.horizontal,
                                "vertical": c.alignment.vertical,
                                "wrap_text": bool(c.alignment.wrap_text),
                            },
                            "border": {
                                "left": side(c.border.left),
                                "right": side(c.border.right),
                                "top": side(c.border.top),
                                "bottom": side(c.border.bottom),
                            },
                        }
                    )
            sheets.append(
                {
                    "name": ws.title,
                    "merged_ranges": sorted(str(r) for r in ws.merged_cells.ranges),
                    "freeze_panes": str(ws.freeze_panes) if ws.freeze_panes else None,
                    "show_grid_lines": bool(ws.sheet_view.showGridLines),
                    "column_widths": {
                        key: _round_number(dim.width)
                        for key, dim in sorted(ws.column_dimensions.items())
                        if dim.width is not None
                    },
                    "row_heights": {
                        str(key): _round_number(dim.height)
                        for key, dim in sorted(ws.row_dimensions.items())
                        if dim.height is not None
                    },
                    "cells": sorted(cells, key=lambda x: x["coordinate"]),
                }
            )
        return {"sheet_order": wb.sheetnames, "sheets": sheets}
    finally:
        wb.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("xlsx")
    parser.add_argument("--output")
    args = parser.parse_args()
    data = contract(Path(args.xlsx))
    rendered = json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True)
    if args.output:
        Path(args.output).write_text(rendered + "\n", encoding="utf-8")
    else:
        print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
