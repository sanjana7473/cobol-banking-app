#!/usr/bin/env bash
# Deploy & run the pipeline on a target environment, then pull the report back.
#
# Usage: deploy-env.sh <A|B> <host> [user]
#   ENV label  -> results subdir env-a / env-b
#   host       -> "localhost" runs on the Jenkins agent; otherwise a remote host
#   user       -> SSH user (required for remote hosts)
#
# Env vars:
#   REMOTE_DIR    remote install dir (default ~/cobol-banking-app)
#   TK5_PRINTER   absolute printer-file path ON THE TARGET for non-default TK5 installs
#
# The target runs the full pipeline (compile + run) on its own local mainframe,
# so each environment's build time is measured independently for the comparison.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

ENV="$(echo "${1:-A}" | tr '[:upper:]' '[:lower:]')"
HOST="${2:-localhost}"
USER="${3:-}"
REMOTE_DIR="${REMOTE_DIR:-~/cobol-banking-app}"
PRINTER_REL="hercules/tk5/prt/prt00e.txt"   # native TK5, relative to the install dir

OUT="$RESULTS_DIR/env-$ENV"
mkdir -p "$OUT"

if is_local "$HOST"; then
    echo "Deploy $ENV -> local"
    python3 "$PIPELINE" all \
        --host 127.0.0.1 --port "$MF_PORT" \
        --syslog-url "$SYSLOG_URL" \
        --printer "$(printer_file)" \
        --report-out "$OUT/report.txt" \
        --timing-out "$OUT/run-timing.json"
else
    echo "Deploy $ENV -> $USER@$HOST ($REMOTE_DIR)"

    # 1) copy the source tree to the target (rsync creates the dir and expands
    #    '~' on the remote; the multi-GB hercules/ TK5 install is excluded and
    #    expected to already exist on the target from provisioning).
    rsync -az --delete \
        --exclude '.git' --exclude '__pycache__' --exclude 'results' --exclude 'hercules' \
        -e "ssh ${SSH_OPTS[*]}" \
        "$REPO_ROOT/" "$USER@$HOST:$REMOTE_DIR/"

    # 2) run the full pipeline on the target's local mainframe.
    #    Unquoted heredoc: only $PRINTER_REL, $ENV and ${TK5_PRINTER} are baked in
    #    locally; everything else (\$-prefixed) expands on the remote shell.
    ssh "${SSH_OPTS[@]}" "$USER@$HOST" 'bash -s' <<EOF
set -e
R_DIR="\$HOME/cobol-banking-app"
R_PTR="\$R_DIR/$PRINTER_REL"
R_OUT="\$R_DIR/results/env-$ENV"
[[ -n "${TK5_PRINTER:-}" ]] && R_PTR="${TK5_PRINTER}"
mkdir -p "\$R_OUT"
cd "\$R_DIR"
python3 ci/pipeline.py all --host 127.0.0.1 --port 3505 --syslog-url http://127.0.0.1:8038/cgi-bin/tasks/syslog --printer "\$R_PTR" --report-out "\$R_OUT/report.txt" --timing-out "\$R_OUT/run-timing.json"
EOF

    # 3) pull the results back
    rsync -az -e "ssh ${SSH_OPTS[*]}" \
        "$USER@$HOST:$REMOTE_DIR/results/env-$ENV/" "$OUT/"
fi

echo "Deploy $ENV complete -> $OUT"
ls -la "$OUT" || true
