#!/usr/bin/env bash
# Shared helpers for the CI shell scripts. Source with: source "$(dirname "$0")/lib.sh"
# shellcheck disable=SC2034

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$REPO_ROOT/results"
PIPELINE="$SCRIPT_DIR/pipeline.py"

# --- Mainframe target for compile / integration (port 3505 reader, 8038 syslog)
MF_HOST="${MF_HOST:-127.0.0.1}"
MF_PORT="${MF_PORT:-3505}"
SYSLOG_URL="${SYSLOG_URL:-http://127.0.0.1:8038/cgi-bin/tasks/syslog}"

# --- Submission transport + FTP (consumed by ci/pipeline.py) ---------------
MF_SUBMIT="${MF_SUBMIT:-ftp}"
FTP_HOST="${FTP_HOST:-127.0.0.1}"
FTP_PORT="${FTP_PORT:-2121}"
FTP_USER="${FTP_USER:-herc01}"
FTP_PASS="${FTP_PASS:-cul8tr}"
export MF_SUBMIT FTP_HOST FTP_PORT FTP_USER FTP_PASS

# --- Printer file (TK5 native) containing JES2 output.
#     Native TK5:  <repo>/hercules/tk5/prt/prt00e.txt
#     Docker TK4:  fetched via `docker exec tk4 cat /tk4-/prt/prt00e.txt`
# TK5_PRINTER (set by Jenkins) overrides the local default; printer_file() below
# resolves the actual path without mutating this variable.

now_ms() { python3 -c 'import time; print(int(time.time() * 1000))'; }

# True (return 0) if the host is the local machine.
is_local() { [[ -z "${1:-}" || "$1" == "localhost" || "$1" == "127.0.0.1" ]]; }

# ssh options for non-interactive, first-contact hosts.
SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new)

# Locate a usable printer file on the local machine:
#   - if $TK5_PRINTER exists, use it
#   - else if a `tk4` container is running, dump its printer file to /tmp
printer_file() {
    local p="${TK5_PRINTER:-$REPO_ROOT/hercules/tk5/prt/prt00e.txt}"
    if [[ -f "$p" ]]; then
        echo "$p"
    elif docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'tk4'; then
        local tmp="/tmp/prt00e.txt"
        docker exec tk4 cat /tk4-/prt/prt00e.txt > "$tmp" 2>/dev/null || true
        echo "$tmp"
    else
        echo "$p"   # may not exist yet; caller decides what to do
    fi
}
