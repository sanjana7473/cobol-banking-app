#!/bin/bash
#
# run_hercules.sh — Boot TK5 (Turnkey 5) MVS 3.8j on Hercules
#
# TK5 is a pre-built turnkey distribution. This script uses TK5's
# own startup script to boot Hercules with the correct configuration.
#
# Usage:
#   bash run_hercules.sh
#

set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
TK5_DIR="${BASE_DIR}/hercules/tk5"

echo "============================================"
echo " Booting MVS 3.8j TK5 on Hercules"
echo "============================================"
echo ""

# ------------------------------------------------------------------
# Check TK5 installation
# ------------------------------------------------------------------
if [ ! -d "${TK5_DIR}" ]; then
    echo "ERROR: TK5 directory not found:"
    echo "  ${TK5_DIR}"
    echo ""
    echo "Run:"
    echo "  bash setup_tk5.sh"
    exit 1
fi

# ------------------------------------------------------------------
# Find TK5 startup script
# ------------------------------------------------------------------
TK5_START=""

for candidate in \
    "${TK5_DIR}/mvs" \
    "${TK5_DIR}/mvs.sh" \
    "${TK5_DIR}/start.sh" \
    "${TK5_DIR}/start_herc"
do
    if [ -f "${candidate}" ]; then
        TK5_START="${candidate}"
        break
    fi
done

if [ -z "${TK5_START}" ]; then
    echo "ERROR: Could not find TK5 startup script."
    echo ""
    echo "Checked:"
    echo "  mvs"
    echo "  mvs.sh"
    echo "  start.sh"
    echo "  start_herc"
    echo ""
    echo "Location:"
    echo "  ${TK5_DIR}"
    exit 1
fi

# ------------------------------------------------------------------
# Check DASD images
# TK5 uses CKD DASD images (.298, .299, .390, etc.)
# not .aws files.
# ------------------------------------------------------------------

DASD_COUNT=$(
find "${TK5_DIR}/dasd" \
    -type f \
    \( \
        -name "*.190" \
        -o -name "*.191" \
        -o -name "*.192" \
        -o -name "*.248" \
        -o -name "*.249" \
        -o -name "*.290" \
        -o -name "*.291" \
        -o -name "*.292" \
        -o -name "*.293" \
        -o -name "*.298" \
        -o -name "*.299" \
        -o -name "*.390" \
        -o -name "*.391" \
        -o -name "*.392" \
    \) \
    | wc -l
)

if [ "${DASD_COUNT}" -eq 0 ]; then
    echo "ERROR: No TK5 DASD images found."
    echo ""
    echo "Expected files in:"
    echo "  ${TK5_DIR}/dasd/"
    echo ""
    exit 1
fi

# ------------------------------------------------------------------
# Find Hercules configuration
# ------------------------------------------------------------------

HERC_CFG=""

for cfg in \
    "${TK5_DIR}/conf/tk5.cnf" \
    "${TK5_DIR}/conf/tk5_default.cnf"
do
    if [ -f "${cfg}" ]; then
        HERC_CFG="${cfg}"
        break
    fi
done

# ------------------------------------------------------------------
# Display information
# ------------------------------------------------------------------

echo "  TK5 directory:  ${TK5_DIR}"
echo "  Startup script: ${TK5_START}"
echo "  DASD images:    ${DASD_COUNT}"

if [ -n "${HERC_CFG}" ]; then
    echo "  Config file:    ${HERC_CFG}"
fi

echo "  TN3270:         ${HERCULES_CNSLPORT:-127.0.0.1:3270}"
echo ""

# ------------------------------------------------------------------
# Permissions
# ------------------------------------------------------------------

chmod +x "${TK5_START}" 2>/dev/null || true
chmod +x "${TK5_DIR}"/*.sh 2>/dev/null || true

# ------------------------------------------------------------------
# Boot instructions
# ------------------------------------------------------------------

echo "Starting Hercules with TK5..."
echo ""
echo "Connect after IPL completes:"
echo ""
echo "  c3270 localhost:3270"
echo ""
echo "Default TSO:"
echo "  User: HERC01"
echo "  Pass: CUL8TR"
echo ""
echo "Shutdown from Hercules console:"
echo "  quit"
echo ""

# ------------------------------------------------------------------
# Start TK5
# ------------------------------------------------------------------

cd "${TK5_DIR}"

exec "${TK5_START}"