#!/usr/bin/env bash
# Build / Compile stage.
# Resets HERC01.LOAD, allocates it, and compiles all 3 COBOL programs (IKFCBL00).
# Fails the stage if any compile returns a non-zero completion code.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

mkdir -p "$RESULTS_DIR"

python3 "$PIPELINE" compile \
    --host "$MF_HOST" \
    --port "$MF_PORT" \
    --syslog-url "$SYSLOG_URL" \
    --timing-out "$RESULTS_DIR/compile-timing.json"
