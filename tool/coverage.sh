#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/packages/universal_sync"

rm -rf coverage
dart test --coverage=coverage
dart run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --packages="$ROOT/.dart_tool/package_config.json" \
  --report-on=lib

dart run "$ROOT/tool/check_coverage.dart" coverage/lcov.info 95
