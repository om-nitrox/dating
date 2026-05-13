#!/usr/bin/env bash
# Regenerate Dart models + Dio APIs from ../../docs/api/openapi.yaml.
#
# Requires:
#   - Flutter / Dart SDK (matching .fvmrc pin: 3.41.9)
#   - `openapi_generator` dev_dependency enabled in pubspec.yaml
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Running build_runner (openapi_generator)..."
dart run build_runner build --delete-conflicting-outputs

echo "==> Formatting generated code..."
dart format lib/src/generated

echo "==> Done. Diff:"
git status -- lib/src/generated
