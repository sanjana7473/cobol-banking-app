#!/usr/bin/env bash
# Unit Test stage.
# Runs deterministic data/layout integrity checks (Phase 3 will add COBOL test
# drivers). Fails the stage on any mismatch. Emits results/unit-test.xml (JUnit).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

mkdir -p "$RESULTS_DIR"
python3 "$SCRIPT_DIR/unit-test.py"
