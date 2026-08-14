#!/bin/bash
# TK5 FTP Watcher — polls the rdr/ directory and submits new files to TK5.
#
# Env vars:
#   RDR_DIR   directory the FTP server writes uploaded JCL into
#             (default: <repo>/hercules/tk5/rdr)
#   TK5_PORT  JES2 reader port (default 3505)
#
# The FTP server (pure-ftpd) drops uploaded files here; this loop submits each
# new file to TK5's JES2 reader and renames it to .done_<name>.

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
RDR_DIR="${RDR_DIR:-$BASE_DIR/hercules/tk5/rdr}"
TK5_PORT="${TK5_PORT:-3505}"

mkdir -p "$RDR_DIR"

echo "Watching $RDR_DIR for new JCL files..."
echo "Submit port: $TK5_PORT"
echo "Upload: ftp localhost 2121  (user: herc01 / pass: cul8tr)"
echo ""

while true; do
    for f in "$RDR_DIR"/*; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        # Skip hidden files and already-processed
        [[ "$base" == .* ]] && continue

        # Small delay to ensure the upload is complete
        sleep 1

        if [ -f "$f" ] && [ -s "$f" ]; then
            echo "  → Submitting $base to TK5..."
            cat "$f" | nc -w 5 localhost "$TK5_PORT"
            echo "  ✓ Done: $base"
            mv "$f" "$RDR_DIR/.done_$base"
        fi
    done
    sleep 3
done
