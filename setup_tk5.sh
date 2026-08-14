#!/usr/bin/env bash
#
# setup_tk5.sh - Download and install MVS TK5 for Hercules
#
# Usage:
#   ./setup_tk5.sh
#   ./setup_tk5.sh --clean
#

set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
HERCULES_DIR="${BASE_DIR}/hercules"
TK5_DIR="${HERCULES_DIR}/tk5"
BASE_ARCHIVE="${HERCULES_DIR}/mvs-tk5.zip"
BASE_URL="https://www.prince-webdesign.nl/images/downloads/mvs-tk5.zip"

CLEAN=false

usage() {
cat <<EOF
Usage: $0 [options]

Download and install MVS TK5 into:

  $TK5_DIR

Options:
  --clean      Remove downloaded ZIP after extraction
  -h,--help    Show this help

EOF
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            CLEAN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
done

command -v wget >/dev/null || fail "wget is required"
command -v unzip >/dev/null || fail "unzip is required"

mkdir -p "$HERCULES_DIR"

###############################################################################
# Download
###############################################################################

if [[ ! -f "$BASE_ARCHIVE" ]]; then
    echo "Downloading TK5 archive..."
    wget \
        --continue \
        --show-progress \
        --output-document="$BASE_ARCHIVE" \
        "$BASE_URL"
else
    echo "Using existing archive:"
    echo "  $BASE_ARCHIVE"
fi

echo "Validating archive..."
unzip -t "$BASE_ARCHIVE" >/dev/null || fail "Archive validation failed"

###############################################################################
# Extract
###############################################################################

rm -rf "$TK5_DIR"
mkdir -p "$TK5_DIR"

echo "Extracting archive..."
unzip -q "$BASE_ARCHIVE" -d "$TK5_DIR"

###############################################################################
# Flatten directory if archive contains mvs-tk5/
###############################################################################

if [[ -d "$TK5_DIR/mvs-tk5" ]]; then
    echo "Flattening archive structure..."

    shopt -s dotglob

    mv "$TK5_DIR/mvs-tk5"/* "$TK5_DIR"/

    rmdir "$TK5_DIR/mvs-tk5"

    shopt -u dotglob
fi

###############################################################################
# Locate startup script
###############################################################################

TK5_START=$(
find "$TK5_DIR" \
    -type f \
    \( \
        -name mvs \
        -o -name mvs.sh \
        -o -name start.sh \
        -o -name start_herc \
    \) \
| head -n1
)

[[ -n "$TK5_START" ]] || fail "No startup script found."

chmod +x "$TK5_START" 2>/dev/null || true
chmod +x "$TK5_DIR"/*.sh 2>/dev/null || true

###############################################################################
# Locate Hercules configuration
###############################################################################

HERC_CFG=$(
find "$TK5_DIR" \
    -type f \
    \( \
        -name tk5.cnf \
        -o -name tk5_default.cnf \
    \) \
| head -n1
)

###############################################################################
# Count DASD images
###############################################################################

DASD_COUNT=$(
find "$TK5_DIR/dasd" \
    -type f \
    \( \
        -name "*.298" \
        -o -name "*.299" \
        -o -name "*.390" \
        -o -name "*.391" \
        -o -name "*.392" \
        -o -name "*.190" \
        -o -name "*.191" \
        -o -name "*.192" \
        -o -name "*.248" \
        -o -name "*.249" \
        -o -name "*.290" \
        -o -name "*.291" \
        -o -name "*.292" \
        -o -name "*.293" \
    \) \
| wc -l
)

[[ "$DASD_COUNT" -gt 0 ]] || fail "No DASD images found."

###############################################################################
# Cleanup
###############################################################################

if [[ "$CLEAN" == true ]]; then
    rm -f "$BASE_ARCHIVE"
fi

###############################################################################
# Success
###############################################################################

echo
echo "========================================================="
echo "TK5 installation completed successfully."
echo "========================================================="
echo
echo "Installation directory:"
echo "  $TK5_DIR"
echo
echo "Startup script:"
echo "  $TK5_START"
echo

if [[ -n "$HERC_CFG" ]]; then
    echo "Hercules configuration:"
    echo "  $HERC_CFG"
    echo
fi

echo "DASD images found:"
echo "  $DASD_COUNT"
echo

echo "To boot TK5 manually:"
echo
echo "  cd \"$TK5_DIR\""
echo "  ./mvs"
echo

echo "or"

echo
echo "  hercules -f \"$HERC_CFG\""
echo

echo "Done."