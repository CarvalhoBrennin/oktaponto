#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERRO] Python 3 não encontrado. Instale Python 3.11 ou superior." >&2
  exit 1
fi
if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)'; then
  echo "[ERRO] O Python 3 encontrado é anterior a 3.11." >&2
  exit 1
fi

if [ ! -x .venv/bin/python ]; then
  echo "Criando ambiente virtual..."
  python3 -m venv .venv
fi
if ! .venv/bin/python -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)'; then
  echo "[ERRO] A pasta .venv usa Python antigo ou está corrompida. Remova .venv e execute novamente." >&2
  exit 1
fi

.venv/bin/python -m pip install --disable-pip-version-check -r requirements.txt
exec .venv/bin/python main.py
