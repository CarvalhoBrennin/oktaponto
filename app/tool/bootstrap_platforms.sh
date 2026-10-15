#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK não encontrado. Instale Flutter 3.47.2 e execute novamente." >&2
  exit 127
fi

version_line="$(flutter --version | head -n 1)"
if [[ "$version_line" != *"Flutter 3.47.2"* && "${OKTAPONTO_ALLOW_OTHER_FLUTTER:-0}" != "1" ]]; then
  echo "Este projeto foi congelado para Flutter 3.47.2. Encontrado: $version_line" >&2
  echo "Use 3.47.2 ou defina OKTAPONTO_ALLOW_OTHER_FLUTTER=1 conscientemente." >&2
  exit 65
fi

if [[ ! -d android || ! -d ios ]]; then
  flutter create --platforms=android,ios --org com.oktaponto --project-name oktaponto .
fi
flutter pub get
python3 tool/configure_platforms.py
dart run flutter_launcher_icons
