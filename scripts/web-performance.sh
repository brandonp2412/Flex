#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --no-wasm-dry-run
if [[ " $* " != *" --no-stress "* ]]; then
  flutter build web --release --no-wasm-dry-run --target=test_driver/web_performance.dart --base-href=/seed/ --output=build/web-perf
fi
npm ci --prefix scripts/web-perf --ignore-scripts --no-audit --no-fund
if [[ -z "${FLEX_CHROME_BINARY:-}" ]]; then
  if command -v google-chrome >/dev/null 2>&1; then
    export FLEX_CHROME_BINARY="$(command -v google-chrome)"
  elif command -v chromium >/dev/null 2>&1; then
    export FLEX_CHROME_BINARY="$(command -v chromium)"
  else
    (cd scripts/web-perf && npx playwright-core install chromium)
  fi
fi
node scripts/web-perf/run.mjs "$@"
