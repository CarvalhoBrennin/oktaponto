#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."

if [ -x .venv/bin/python ]; then
  PYTHON=.venv/bin/python
elif command -v python3 >/dev/null 2>&1; then
  PYTHON=python3
else
  PYTHON=python
fi

"$PYTHON" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' || {
  echo "[ERRO] Os testes exigem Python 3.11 ou superior." >&2
  exit 1
}
exec "$PYTHON" -m unittest discover -s tests
