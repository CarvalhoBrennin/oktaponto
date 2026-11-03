#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f pubspec.lock ]]; then
  echo "pubspec.lock ausente. Execute Flutter 3.47.2: flutter pub get e versione o arquivo." >&2
  exit 66
fi
flutter pub get --enforce-lockfile
