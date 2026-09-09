#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -d android || ! -d ios ]]; then
  flutter create \
    --platforms=android,ios \
    --org com.example \
    --project-name horafolio \
    .
fi
