#!/usr/bin/env bash
# Run the N-run benchmark on a target environment and pull the results back.
#
# Usage: run-benchmark.sh <A|B> <host> [user]
#   ENV label   -> results subdir env-a / env-b
#   host        -> "localhost" runs on the Jenkins agent; otherwise a remote host
#   user        -> SSH user (required for remote hosts)
#
# Env vars:
#   RUN_COUNT    number of full pipeline runs (default 14)
#   REMOTE_DIR   remote install dir (default ~/cobol-banking-app)
#   TK5_PRINTER  printer-file path ON THE TARGET for non-default TK5 installs
#   MF_SUBMIT    "ftp" (default) or "socket"
#   FTP_HOST/FTP_PORT/FTP_USER/FTP_PASS  FTP server config (default herc01/cul8tr:2121)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

ENV="$(echo "${1:-A}" | tr '[:upper:]' '[:lower:]')"
HOST="${2:-localhost}"
USER="${3:-}"
RUN_COUNT="${RUN_COUNT:-14}"
REMOTE_DIR="${REMOTE_DIR:-~/cobol-banking-app}"
PRINTER_REL="hercules/tk5/prt/prt00e.txt"

OUT="$RESULTS_DIR/env-$ENV"
mkdir -p "$OUT"

if is_local "$HOST"; then
    echo "Benchmark $ENV -> local (${RUN_COUNT} runs, submit=${MF_SUBMIT})"
    python3 "$SCRIPT_DIR/benchmark.py" --runs "$RUN_COUNT" --env "$ENV" \
        --host 127.0.0.1 --port "$MF_PORT" --syslog-url "$SYSLOG_URL" \
        --submit "$MF_SUBMIT" \
        --printer "$(printer_file)" \
        --out "$OUT/benchmark.json"
else
    echo "Benchmark $ENV -> $USER@$HOST (${RUN_COUNT} runs, submit=${MF_SUBMIT})"

    rsync -az --delete \
        --exclude '.git' --exclude '__pycache__' --exclude 'results' --exclude 'hercules' \
        -e "ssh ${SSH_OPTS[*]}" \
        "$REPO_ROOT/" "$USER@$HOST:$REMOTE_DIR/"

    ssh "${SSH_OPTS[@]}" "$USER@$HOST" 'bash -s' <<EOF
set -e
R_DIR="\$HOME/cobol-banking-app"
R_PTR="\$R_DIR/$PRINTER_REL"
[[ -n "${TK5_PRINTER:-}" ]] && R_PTR="${TK5_PRINTER}"
mkdir -p "\$R_DIR/results/env-$ENV"
cd "\$R_DIR"
MF_SUBMIT="${MF_SUBMIT}" FTP_HOST="${FTP_HOST}" FTP_PORT="${FTP_PORT}" FTP_USER="${FTP_USER}" FTP_PASS="${FTP_PASS}" \
python3 ci/benchmark.py --runs ${RUN_COUNT} --env "$ENV" \
  --host 127.0.0.1 --port 3505 --syslog-url http://127.0.0.1:8038/cgi-bin/tasks/syslog \
  --submit "${MF_SUBMIT}" \
  --printer "\$R_PTR" \
  --out "\$R_DIR/results/env-$ENV/benchmark.json"
EOF

    rsync -az -e "ssh ${SSH_OPTS[*]}" \
        "$USER@$HOST:$REMOTE_DIR/results/env-$ENV/" "$OUT/"
fi

echo "Benchmark $ENV complete -> $OUT/benchmark.json"
