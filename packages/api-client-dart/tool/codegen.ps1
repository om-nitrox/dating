# Regenerate Dart models + Dio APIs from ../../docs/api/openapi.yaml.
#
# Requires:
#   - Flutter / Dart SDK (matching .fvmrc pin: 3.41.9)
#   - `openapi_generator` dev_dependency enabled in pubspec.yaml
#
# This script is a thin wrapper. Once the dev_dependency is uncommented and
# `dart pub get` has run, this becomes the single command to regenerate.

$ErrorActionPreference = "Stop"

Push-Location (Join-Path $PSScriptRoot "..")
try {
    Write-Host "==> Running build_runner (openapi_generator)..."
    dart run build_runner build --delete-conflicting-outputs

    Write-Host "==> Formatting generated code..."
    dart format lib/src/generated

    Write-Host "==> Done. Diff:"
    git status -- lib/src/generated
} finally {
    Pop-Location
}
