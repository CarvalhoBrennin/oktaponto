#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p test/goldens/ui
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test --dart-define=HORAFOLIO_UPDATE_GOLDENS=true --update-goldens test/golden_ui_test.dart
flutter test test/golden_ui_test.dart
