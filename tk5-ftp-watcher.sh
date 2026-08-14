#!/bin/bash
# TK5 FTP Watcher — polls rdr/ directory and submits new files to TK5
RDR_DIR="/home/ubuntu/Meshach Cobol Code_Cobol Code/hercules/tk5/rdr"
TK5_PORT=3505

echo "Watching $RDR_DIR for new JCL files..."
echo "Upload: ftp localhost 2121  (user: herc01 / pass: cul8tr)"
echo ""

while true; do
    for f in "$RDR_DIR"/*; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        # Skip hidden files and already-processed
        [[ "$base" == .* ]] && continue
        
        # Small delay to ensure write is complete
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
