#!/bin/bash
# Upload all COBOL source + data files to the FTP server (port 2121)
# Usage: bash upload-ftp.sh [host]

HOST="${1:-localhost}"
BASE="$(cd "$(dirname "$0")/.." && pwd)"

echo "Uploading COBOL files to ftp://dev:devpass@${HOST}:2121/"

curl -s -T "$BASE/cobol/VALDTRAN.cbl" ftp://dev:devpass@${HOST}:2121/VALDTRAN.cbl && echo "  VALDTRAN.cbl"
curl -s -T "$BASE/cobol/UPDTBAL.cbl" ftp://dev:devpass@${HOST}:2121/UPDTBAL.cbl && echo "  UPDTBAL.cbl"
curl -s -T "$BASE/cobol/RPRTGEN.cbl" ftp://dev:devpass@${HOST}:2121/RPRTGEN.cbl && echo "  RPRTGEN.cbl"
curl -s -T "$BASE/cobol/COPYLIB/ACCTREC.cpy" ftp://dev:devpass@${HOST}:2121/ACCTREC.cpy && echo "  ACCTREC.cpy"
curl -s -T "$BASE/cobol/TRANSIN.DAT" ftp://dev:devpass@${HOST}:2121/TRANSIN.DAT && echo "  TRANSIN.DAT"
curl -s -T "$BASE/cobol/ACCTMAST.DAT" ftp://dev:devpass@${HOST}:2121/ACCTMAST.DAT && echo "  ACCTMAST.DAT"

echo ""
echo "Done. Verify: curl -l ftp://dev:devpass@${HOST}:2121/"
