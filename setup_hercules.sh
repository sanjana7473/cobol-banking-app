#!/bin/bash
#
# setup_hercules.sh — Set up MVS 3.8j TK5 for the Hercules emulator
#
# TK5 is a pre-built, turnkey MVS 3.8j distribution. No SYSGEN needed.
# This script guides you through downloading and extracting TK5.
#
# Download: https://www.prince-webdesign.nl/tk5
#

set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
HERCULES_DIR="${BASE_DIR}/hercules"
TK5_DIR="${HERCULES_DIR}/tk5"

echo "============================================"
echo " MVS 3.8j TK5 Setup for Hercules Emulator"
echo "============================================"
echo ""
echo "TK5 is a pre-built, ready-to-run MVS 3.8j system."
echo "No SYSGEN required — just download, extract, and boot."
echo ""

# ------------------------------------------------------------------
# Step 1: Check/install Hercules
# ------------------------------------------------------------------
echo "--- Step 1: Checking Hercules emulator ---"
if command -v hercules &>/dev/null; then
    echo "  Hercules found: $(hercules --version 2>&1 | head -1)"
else
    echo "  Hercules NOT found. Installing..."
    sudo apt-get update -qq && sudo apt-get install -y -qq hercules
    echo "  Hercules installed: $(hercules --version 2>&1 | head -1)"
fi

# ------------------------------------------------------------------
# Step 2: Create directory
# ------------------------------------------------------------------
echo ""
echo "--- Step 2: Creating TK5 directory ---"
mkdir -p "${TK5_DIR}"
echo "  Directory: ${TK5_DIR}"

# ------------------------------------------------------------------
# Step 3: Check if TK5 is already extracted
# ------------------------------------------------------------------
echo ""
echo "--- Step 3: Checking for existing TK5 installation ---"
TK5_READY=false
if [ -f "${TK5_DIR}/mvs" ] || [ -f "${TK5_DIR}/mvs.sh" ]; then
    echo "  TK5 startup script found."
    TK5_READY=true
fi
if ls "${TK5_DIR}/dasd/"*.aws &>/dev/null 2>&1; then
    DASD_COUNT=$(ls -1 "${TK5_DIR}/dasd/"*.aws 2>/dev/null | wc -l)
    echo "  DASD images found: ${DASD_COUNT}"
    TK5_READY=true
fi

if [ "$TK5_READY" = "true" ]; then
    echo ""
    echo "  ✅ TK5 appears to be already installed."
    echo ""
    echo "  To boot:  bash run_hercules.sh"
    echo ""
    exit 0
fi

# ------------------------------------------------------------------
# Step 4: Download instructions
# ------------------------------------------------------------------
echo ""
echo "  TK5 is NOT yet installed. Follow these steps:"
echo ""
echo "============================================"
echo " DOWNLOAD AND INSTALL TK5"
echo "============================================"
echo ""
echo "  1. VISIT: https://www.prince-webdesign.nl/tk5"
echo ""
echo "     Download these two files:"
echo "       • MVS TK5 base system (ZIP, ~400 MB)"
echo "       • Update 5 (cumulative ZIP, mandatory)"
echo ""
echo "  2. MOVE the ZIP files to:"
echo "     ${HERCULES_DIR}/"
echo ""
echo "     Example:"
echo "     mv ~/Downloads/mvs-tk5.zip \"${HERCULES_DIR}/\""
echo "     mv ~/Downloads/tk5-update5.zip \"${HERCULES_DIR}/\""
echo ""
echo "  3. EXTRACT the base system:"
echo "     cd \"${HERCULES_DIR}\""
echo "     unzip mvs-tk5.zip -d tk5/"
echo ""
echo "  4. APPLY Update 5 (overwrite when prompted):"
echo "     unzip -o tk5-update5.zip -d tk5/"
echo ""
echo "  5. MAKE scripts executable:"
echo "     cd tk5"
echo "     chmod +x mvs *.sh"
echo ""
echo "  6. CLEAN UP ZIP files:"
echo "     rm ../mvs-tk5.zip ../tk5-update5.zip"
echo ""
echo "  7. BOOT TK5:"
echo "     cd \"${BASE_DIR}\""
echo "     bash run_hercules.sh"
echo ""
echo "============================================"
echo ""
echo "  Once installed, default TSO credentials:"
echo "    HERC01 / CUL8TR"
echo "    HERC02 / CUL8TR"
echo "    HERC03 / PASS4U"
echo "    HERC04 / PASS4U"
echo ""
