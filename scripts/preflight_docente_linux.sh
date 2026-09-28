#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo '=== PREFLIGHT DOCENTE · PROYECTO FINAL 360 ==='
flutter --version
flutter doctor
flutter devices
flutter pub get
flutter analyze
flutter test
echo 'OK: pub get + analyze + test completados.'
echo 'Configure config/local.json y ejecute flutter run --dart-define-from-file=config/local.json'
