#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("expected")
    parser.add_argument("actual")
    args = parser.parse_args()
    expected = json.loads(Path(args.expected).read_text(encoding="utf-8"))
    actual = json.loads(Path(args.actual).read_text(encoding="utf-8"))
    if expected == actual:
        print("XLSX semantic contract: OK")
        return 0
    a = json.dumps(expected, ensure_ascii=False, indent=2, sort_keys=True).splitlines()
    b = json.dumps(actual, ensure_ascii=False, indent=2, sort_keys=True).splitlines()
    print("\n".join(difflib.unified_diff(a, b, fromfile="expected", tofile="actual", lineterm="")))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
