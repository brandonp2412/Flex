#!/usr/bin/env bash
# Shared quality check used by CI: verify release contract, generate, format, analyze, and test.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# A clean CI checkout has no package configuration. Running build_runner via
# `dart` cannot resolve Flutter SDK dependencies on its own.
python3 scripts/check-release-invariants.py --base-ref "${FLEX_BASE_REF:-HEAD^}"
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
flutter pub get --enforce-lockfile
dart run build_runner build

echo "== formatting =="
dart format --output=none --set-exit-if-changed lib test integration_test

git diff --exit-code -- lib test pubspec.lock

echo "== analyzing =="
flutter analyze

echo "== testing =="
flutter test
