#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1 || ! command -v dart >/dev/null 2>&1; then
  echo 'Flutter/Dart não encontrados. O gate de release exige Flutter 3.47.2.' >&2
  exit 127
fi

./tool/bootstrap_platforms.sh
flutter pub get

if [[ ! -f pubspec.lock ]]; then
  echo 'pubspec.lock não foi gerado.' >&2
  exit 66
fi
if [[ -n "$(git status --porcelain -- pubspec.lock 2>/dev/null || true)" ]]; then
  echo 'pubspec.lock não está versionado ou está divergente. Gere-o e faça commit antes da release.' >&2
  exit 67
fi

for golden in \
  test/goldens/ui/today_empty.png \
  test/goldens/ui/today_working.png \
  test/goldens/ui/today_complete.png; do
  if [[ ! -f "$golden" ]]; then
    echo "Golden ausente: $golden. Execute ./tool/update_goldens.sh e versione o resultado." >&2
    exit 68
  fi
done

dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage

if [[ -n "${OKTAPONTO_DEVICE_ID:-}" ]]; then
  flutter test integration_test -d "$OKTAPONTO_DEVICE_ID"
else
  echo 'OKTAPONTO_DEVICE_ID não definido; smoke E2E móvel é obrigatório para release.' >&2
  exit 69
fi

dart run tool/generate_fixture.dart \
  --fixture test/fixtures/timesheet_cases.json \
  --output build/dart_actual.xlsx
python ../scripts/xlsx_contract.py build/dart_actual.xlsx \
  --output build/actual_contract.json
python ../scripts/compare_xlsx_contract.py \
  test/goldens/xlsx/reference_contract.json \
  build/actual_contract.json

echo 'Release gate aprovado.'
