#!/usr/bin/env bash
# Collect Results stage.
# Summarises the results gathered from both environments. Fails if Environment A
# is missing (Environment B is optional until provisioning completes in Phase 6).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

echo "=== Collected results ==="
for e in env-a env-b; do
    d="$RESULTS_DIR/$e"
    if [[ -f "$d/report.txt" ]]; then
        lines="$(wc -l < "$d/report.txt")"
        timing="$(cat "$d/run-timing.json" 2>/dev/null || echo 'n/a')"
        echo "  $e: $lines report lines | timing: $timing"
    else
        echo "  $e: MISSING"
    fi
done

[[ -f "$RESULTS_DIR/env-a/report.txt" ]] || { echo "ERROR: env-a report missing" >&2; exit 1; }
echo "Collect OK"
