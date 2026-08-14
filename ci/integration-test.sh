#!/usr/bin/env bash
# Integration Test stage.
# Runs BANKRUN on the CI mainframe (programs must already be compiled by the
# Build/Compile stage) and diffs the report against the golden expected output
# (date-normalized). Fails the stage on any return-code or report mismatch.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

mkdir -p "$RESULTS_DIR"
PRINTER="$(printer_file)"

python3 "$PIPELINE" run \
    --host "$MF_HOST" \
    --port "$MF_PORT" \
    --syslog-url "$SYSLOG_URL" \
    --printer "$PRINTER" \
    --report-out "$RESULTS_DIR/integration-report.txt" \
    --timing-out "$RESULTS_DIR/integration-timing.json"

python3 "$SCRIPT_DIR/compare-report.py" \
    "$RESULTS_DIR/integration-report.txt" \
    "$REPO_ROOT/reports/EXPECTED_OUTPUT.txt" \
    --normalize
