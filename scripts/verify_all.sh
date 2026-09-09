#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo '== Legacy Python oracle =='
(
  cd legacy/python_reference
  python -m unittest discover -s tests
)

if ! command -v flutter >/dev/null 2>&1 || ! command -v dart >/dev/null 2>&1; then
  echo 'Flutter/Dart não encontrados; gates móveis não executados.' >&2
  exit 127
fi

echo '== Flutter bootstrap / generated code =='
(
  cd app
  ./tool/bootstrap_platforms.sh
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  dart format --output=none --set-exit-if-changed .
  flutter analyze
  flutter test --coverage
  flutter test integration_test
)

echo '== XLSX Python oracle =='
mkdir -p app/build
python scripts/generate_reference_fixture.py \
  --fixture app/test/fixtures/timesheet_cases.json \
  --output app/build/python_reference.xlsx
python scripts/xlsx_contract.py app/build/python_reference.xlsx \
  --output app/build/reference_current.json
python scripts/compare_xlsx_contract.py \
  app/test/goldens/xlsx/reference_contract.json \
  app/build/reference_current.json

echo '== XLSX Dart implementation =='
(
  cd app
  dart run tool/generate_fixture.dart \
    --fixture test/fixtures/timesheet_cases.json \
    --output build/dart_actual.xlsx
)
python scripts/xlsx_contract.py app/build/dart_actual.xlsx \
  --output app/build/actual_contract.json
python scripts/compare_xlsx_contract.py \
  app/test/goldens/xlsx/reference_contract.json \
  app/build/actual_contract.json

echo 'All available gates passed.'
