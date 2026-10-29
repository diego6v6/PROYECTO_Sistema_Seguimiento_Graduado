#!/usr/bin/env bash
set -o pipefail
suite="${1:-all}"
case "$suite" in
  functional) targets=(test/functional test/unit) ;;
  security) targets=(test/security) ;;
  all) targets=(test) ;;
  *) echo 'Uso: bash scripts/ejecutar_pruebas.sh [functional|security|all]' >&2; exit 2 ;;
esac
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 2
mkdir -p evidencias/reportes
stamp="$(date +%Y%m%d_%H%M%S)"
log="evidencias/reportes/ejecucion_${suite}_${stamp}.log"
flutter test "${targets[@]}" 2>&1 | tee "$log"
code=${PIPESTATUS[0]}
printf '\nExit code: %s\nSuite: %s\n' "$code" "$suite" | tee -a "$log"
exit "$code"
