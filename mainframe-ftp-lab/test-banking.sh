#!/bin/bash
# Full Banking Application Test Script (v3 - file-based JCL submission)
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
JCL_DIR="$BASE_DIR/jcl"
COBOL_DIR="$BASE_DIR/cobol"
HOST="localhost"
CARD_PORT="3505"

echo "============================================"
echo "🏦 COBOL Banking App - Automated Test v3"
echo "============================================"

# Helper: submit JCL file via Python socket
submit_file() {
    local file="$1"
    local desc="$2"
    echo "📤 Submitting: $desc ($(wc -c < "$file") bytes)"
    python3 -c "
import socket, time
with open('$file', 'rb') as f:
    data = f.read()
s = socket.socket()
s.settimeout(15)
s.connect(('$HOST', $CARD_PORT))
s.send(data)
time.sleep(0.5)
s.close()
print('  ✅ Sent')
"
}

# Generate JCL file from heredoc
make_jcl() {
    local out="$1"
    cat > "$out"
}

RAKF="USER=HERC01,PASSWORD=CUL8TR"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# -------------------------------------------------------------------
# Step 0: Cleanup
# -------------------------------------------------------------------
echo "--- Step 0: Cleanup old datasets ---"
make_jcl "$TMPDIR/cleanup.jcl" << ENDJCL
//CLEANUP  JOB (ACCT),'CLEANUP',CLASS=A,MSGCLASS=A,$RAKF
//STEP1    EXEC PGM=IEFBR14
//DD1      DD DSN=HERC01.COBOL,DISP=(OLD,DELETE)
//DD2      DD DSN=HERC01.COPYLIB,DISP=(OLD,DELETE)
//DD3      DD DSN=HERC01.LOAD,DISP=(OLD,DELETE)
//DD4      DD DSN=HERC01.JCL,DISP=(OLD,DELETE)
//DD5      DD DSN=HERC01.TRANSIN,DISP=(OLD,DELETE)
//DD6      DD DSN=HERC01.ACCTMAST,DISP=(OLD,DELETE)
//DD7      DD DSN=HERC01.VALIDATE,DISP=(OLD,DELETE)
//DD8      DD DSN=HERC01.ACCTUPD,DISP=(OLD,DELETE)
//DD9      DD DSN=HERC01.TESTDS,DISP=(OLD,DELETE)
//SYSOUT   DD SYSOUT=*
//
ENDJCL
submit_file "$TMPDIR/cleanup.jcl" "Cleanup"
sleep 8

# -------------------------------------------------------------------
# Step 1: Allocate
# -------------------------------------------------------------------
echo "--- Step 1: Allocate datasets ---"
make_jcl "$TMPDIR/alloc.jcl" << ENDJCL
//ALLOC    JOB (ACCT),'ALLOC',CLASS=A,MSGCLASS=A,$RAKF
//STEP1    EXEC PGM=IEFBR14
//COBOL    DD DSN=HERC01.COBOL,DISP=(NEW,CATLG),
//             UNIT=SYSDA,SPACE=(CYL,(1,1,10)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//COPYLIB  DD DSN=HERC01.COPYLIB,DISP=(NEW,CATLG),
//             UNIT=SYSDA,SPACE=(TRK,(1,1,5)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//LOAD     DD DSN=HERC01.LOAD,DISP=(NEW,CATLG),
//             UNIT=SYSDA,SPACE=(CYL,(1,1,10)),
//             DCB=(RECFM=U,LRECL=0,BLKSIZE=32760)
//JCLDS    DD DSN=HERC01.JCL,DISP=(NEW,CATLG),
//             UNIT=SYSDA,SPACE=(TRK,(1,1,10)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//TRANSIN DD DSN=HERC01.TRANSIN,DISP=(NEW,CATLG),
//             UNIT=SYSDA,SPACE=(TRK,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//ACCTMAST DD DSN=HERC01.ACCTMAST,DISP=(NEW,CATLG),
//             UNIT=SYSDA,SPACE=(TRK,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//SYSOUT   DD SYSOUT=*
//
ENDJCL
submit_file "$TMPDIR/alloc.jcl" "Allocate"
sleep 8

# -------------------------------------------------------------------
# Step 2: Populate COBOL, COPYLIB, and data
# -------------------------------------------------------------------
echo "--- Step 2: Populating COBOL members ---"

# VALDTRAN
{
    echo "//VALDPOP  JOB (ACCT),'POP-VALD',CLASS=A,MSGCLASS=A,$RAKF"
    echo "//STEP1    EXEC PGM=IEBUPDTE,PARM=NEW"
    echo "//SYSPRINT DD SYSOUT=*"
    echo "//SYSUT1   DD DSN=HERC01.COBOL,DISP=SHR"
    echo "//SYSUT2   DD DSN=HERC01.COBOL,DISP=SHR"
    echo "//SYSIN    DD DATA"
    echo "./ ADD NAME=VALDTRAN"
    cat "$COBOL_DIR/VALDTRAN.cbl"
    echo "./ ENDUP"
    echo "//"
} > "$TMPDIR/pop_vald.jcl"
submit_file "$TMPDIR/pop_vald.jcl" "VALDTRAN source"
sleep 5

# UPDTBAL
{
    echo "//UPDTPOP  JOB (ACCT),'POP-UPDT',CLASS=A,MSGCLASS=A,$RAKF"
    echo "//STEP1    EXEC PGM=IEBUPDTE,PARM=NEW"
    echo "//SYSPRINT DD SYSOUT=*"
    echo "//SYSUT1   DD DSN=HERC01.COBOL,DISP=SHR"
    echo "//SYSUT2   DD DSN=HERC01.COBOL,DISP=SHR"
    echo "//SYSIN    DD DATA"
    echo "./ ADD NAME=UPDTBAL"
    cat "$COBOL_DIR/UPDTBAL.cbl"
    echo "./ ENDUP"
    echo "//"
} > "$TMPDIR/pop_updt.jcl"
submit_file "$TMPDIR/pop_updt.jcl" "UPDTBAL source"
sleep 5

# RPRTGEN
{
    echo "//RPTPOP   JOB (ACCT),'POP-RPRT',CLASS=A,MSGCLASS=A,$RAKF"
    echo "//STEP1    EXEC PGM=IEBUPDTE,PARM=NEW"
    echo "//SYSPRINT DD SYSOUT=*"
    echo "//SYSUT1   DD DSN=HERC01.COBOL,DISP=SHR"
    echo "//SYSUT2   DD DSN=HERC01.COBOL,DISP=SHR"
    echo "//SYSIN    DD DATA"
    echo "./ ADD NAME=RPRTGEN"
    cat "$COBOL_DIR/RPRTGEN.cbl"
    echo "./ ENDUP"
    echo "//"
} > "$TMPDIR/pop_rprt.jcl"
submit_file "$TMPDIR/pop_rprt.jcl" "RPRTGEN source"
sleep 5

# COPYLIB
{
    echo "//COPYPOP  JOB (ACCT),'POP-COPY',CLASS=A,MSGCLASS=A,$RAKF"
    echo "//STEP1    EXEC PGM=IEBUPDTE,PARM=NEW"
    echo "//SYSPRINT DD SYSOUT=*"
    echo "//SYSUT1   DD DSN=HERC01.COPYLIB,DISP=SHR"
    echo "//SYSUT2   DD DSN=HERC01.COPYLIB,DISP=SHR"
    echo "//SYSIN    DD DATA"
    echo "./ ADD NAME=ACCTREC"
    cat "$COBOL_DIR/COPYLIB/ACCTREC.cpy"
    echo "./ ENDUP"
    echo "//"
} > "$TMPDIR/pop_copy.jcl"
submit_file "$TMPDIR/pop_copy.jcl" "COPYLIB(ACCTREC)"
sleep 5

# TRANSIN data
{
    echo "//TRANPOP  JOB (ACCT),'POP-TRANS',CLASS=A,MSGCLASS=A,$RAKF"
    echo "//STEP1    EXEC PGM=IEBGENER"
    echo "//SYSUT1   DD DATA"
    cat "$COBOL_DIR/TRANSIN.DAT"
    echo "//SYSUT2   DD DSN=HERC01.TRANSIN,DISP=SHR"
    echo "//SYSPRINT DD SYSOUT=*"
    echo "//SYSIN    DD DUMMY"
    echo "//"
} > "$TMPDIR/pop_trans.jcl"
submit_file "$TMPDIR/pop_trans.jcl" "TRANSIN data"
sleep 5

# ACCTMAST data
{
    echo "//ACCTPOP  JOB (ACCT),'POP-ACCTS',CLASS=A,MSGCLASS=A,$RAKF"
    echo "//STEP1    EXEC PGM=IEBGENER"
    echo "//SYSUT1   DD DATA"
    cat "$COBOL_DIR/ACCTMAST.DAT"
    echo "//SYSUT2   DD DSN=HERC01.ACCTMAST,DISP=SHR"
    echo "//SYSPRINT DD SYSOUT=*"
    echo "//SYSIN    DD DUMMY"
    echo "//"
} > "$TMPDIR/pop_accts.jcl"
submit_file "$TMPDIR/pop_accts.jcl" "ACCTMAST data"

echo "  ⏳ Waiting 15s for population jobs..."
sleep 15

# -------------------------------------------------------------------
# Step 3: Compile & run each program
# -------------------------------------------------------------------
echo "--- Step 3: Compiling & running programs ---"

# VALDTRAN compile+link+run
make_jcl "$TMPDIR/comp_vald.jcl" << 'ENDJCL'
//VALDCOMP JOB (ACCT),'COMP-VALD',CLASS=A,MSGCLASS=A,USER=HERC01,PASSWORD=CUL8TR
//COBOL    EXEC COBUCG,PARM.COB='LOAD,NODECK'
//COBOL.SYSIN DD DSN=HERC01.COBOL(VALDTRAN),DISP=SHR
//COBOL.SYSLIB DD DSN=HERC01.COPYLIB,DISP=SHR
//COBOL.SYSPRINT DD SYSOUT=*
//COBOL.SYSLIN DD DSN=&&LOADSET,DISP=(MOD,PASS),
//             UNIT=SYSDA,SPACE=(CYL,(1,1))
//LKED     EXEC PGM=IEWL,PARM='LIST,XREF'
//SYSLIN   DD DSN=&&LOADSET,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=HERC01.LOAD(VALDTRAN),DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSPRINT DD SYSOUT=*
//RUN      EXEC PGM=VALDTRAN
//STEPLIB  DD DSN=HERC01.LOAD,DISP=SHR
//TRANSIN DD DSN=HERC01.TRANSIN,DISP=SHR
//VALIDATE DD DSN=HERC01.VALIDATE,DISP=(NEW,CATLG),
//             UNIT=SYSDA,SPACE=(TRK,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//VALERRORS DD SYSOUT=*
//ACCTMAST DD DSN=HERC01.ACCTMAST,DISP=SHR
//SYSOUT   DD SYSOUT=*
//
ENDJCL
submit_file "$TMPDIR/comp_vald.jcl" "Compile+Run VALDTRAN"
sleep 10

# UPDTBAL compile+link+run
make_jcl "$TMPDIR/comp_updt.jcl" << 'ENDJCL'
//UPDTCOMP JOB (ACCT),'COMP-UPDT',CLASS=A,MSGCLASS=A,USER=HERC01,PASSWORD=CUL8TR
//COBOL    EXEC COBUCG,PARM.COB='LOAD,NODECK'
//COBOL.SYSIN DD DSN=HERC01.COBOL(UPDTBAL),DISP=SHR
//COBOL.SYSLIB DD DSN=HERC01.COPYLIB,DISP=SHR
//COBOL.SYSPRINT DD SYSOUT=*
//COBOL.SYSLIN DD DSN=&&LOADSET,DISP=(MOD,PASS),
//             UNIT=SYSDA,SPACE=(CYL,(1,1))
//LKED     EXEC PGM=IEWL,PARM='LIST,XREF'
//SYSLIN   DD DSN=&&LOADSET,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=HERC01.LOAD(UPDTBAL),DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSPRINT DD SYSOUT=*
//RUN      EXEC PGM=UPDTBAL
//STEPLIB  DD DSN=HERC01.LOAD,DISP=SHR
//VALIDATE DD DSN=HERC01.VALIDATE,DISP=SHR
//ACCTMAST DD DSN=HERC01.ACCTMAST,DISP=SHR
//ACCTUPD  DD DSN=HERC01.ACCTUPD,DISP=(NEW,CATLG),
//             UNIT=SYSDA,SPACE=(TRK,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//UPDATERPT DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//
ENDJCL
submit_file "$TMPDIR/comp_updt.jcl" "Compile+Run UPDTBAL"
sleep 10

# RPRTGEN compile+link+run
make_jcl "$TMPDIR/comp_rprt.jcl" << 'ENDJCL'
//RPRTCOMP JOB (ACCT),'COMP-RPRT',CLASS=A,MSGCLASS=A,USER=HERC01,PASSWORD=CUL8TR
//COBOL    EXEC COBUCG,PARM.COB='LOAD,NODECK'
//COBOL.SYSIN DD DSN=HERC01.COBOL(RPRTGEN),DISP=SHR
//COBOL.SYSLIB DD DSN=HERC01.COPYLIB,DISP=SHR
//COBOL.SYSPRINT DD SYSOUT=*
//COBOL.SYSLIN DD DSN=&&LOADSET,DISP=(MOD,PASS),
//             UNIT=SYSDA,SPACE=(CYL,(1,1))
//LKED     EXEC PGM=IEWL,PARM='LIST,XREF'
//SYSLIN   DD DSN=&&LOADSET,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=HERC01.LOAD(RPRTGEN),DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSPRINT DD SYSOUT=*
//RUN      EXEC PGM=RPRTGEN
//STEPLIB  DD DSN=HERC01.LOAD,DISP=SHR
//ACCTUPD  DD DSN=HERC01.ACCTUPD,DISP=SHR
//TRANSIN DD DSN=HERC01.TRANSIN,DISP=SHR
//FINALRPT DD SYSOUT=*
//SUMMARY  DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//
ENDJCL
submit_file "$TMPDIR/comp_rprt.jcl" "Compile+Run RPRTGEN"
sleep 10

# -------------------------------------------------------------------
# Step 4: BANKRUN
# -------------------------------------------------------------------
echo "--- Step 4: BANKRUN master pipeline ---"
make_jcl "$TMPDIR/bankrun.jcl" << 'ENDJCL'
//BANKRUN  JOB (ACCT),'BANK-RUN',CLASS=A,MSGCLASS=A,USER=HERC01,PASSWORD=CUL8TR
//VALD     EXEC PGM=VALDTRAN
//STEPLIB  DD DSN=HERC01.LOAD,DISP=SHR
//TRANSIN DD DSN=HERC01.TRANSIN,DISP=SHR
//VALIDATE DD DSN=&&VALIDATE,DISP=(NEW,PASS),
//             UNIT=SYSDA,SPACE=(TRK,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//VALERRORS DD SYSOUT=*
//ACCTMAST DD DSN=HERC01.ACCTMAST,DISP=SHR
//SYSOUT   DD SYSOUT=*
//UPDT     EXEC PGM=UPDTBAL
//STEPLIB  DD DSN=HERC01.LOAD,DISP=SHR
//VALIDATE DD DSN=&&VALIDATE,DISP=(OLD,DELETE)
//ACCTMAST DD DSN=HERC01.ACCTMAST,DISP=SHR
//ACCTUPD  DD DSN=&&ACCTUPD,DISP=(NEW,PASS),
//             UNIT=SYSDA,SPACE=(TRK,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//UPDATERPT DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//RPT      EXEC PGM=RPRTGEN
//STEPLIB  DD DSN=HERC01.LOAD,DISP=SHR
//ACCTUPD  DD DSN=&&ACCTUPD,DISP=(OLD,DELETE)
//TRANSIN DD DSN=HERC01.TRANSIN,DISP=SHR
//FINALRPT DD SYSOUT=*
//SUMMARY  DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//
ENDJCL
submit_file "$TMPDIR/bankrun.jcl" "BANKRUN"
sleep 15

# -------------------------------------------------------------------
# Step 5: Verify
# -------------------------------------------------------------------
echo "--- Step 5: Verify output ---"
make_jcl "$TMPDIR/check.jcl" << ENDJCL
//CHECK    JOB (ACCT),'VERIFY',CLASS=A,MSGCLASS=A,$RAKF
//L1       EXEC PGM=IEBGENER
//SYSUT1   DD DSN=HERC01.TRANSIN,DISP=SHR
//SYSUT2   DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DUMMY
//L2       EXEC PGM=IEBGENER
//SYSUT1   DD DSN=HERC01.ACCTMAST,DISP=SHR
//SYSUT2   DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DUMMY
//L3       EXEC PGM=IEBGENER
//SYSUT1   DD DSN=HERC01.ACCTUPD,DISP=SHR
//SYSUT2   DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DUMMY
//
ENDJCL
submit_file "$TMPDIR/check.jcl" "Verify"

echo ""
echo "============================================"
echo "✅ All jobs submitted! (v3 file-based)"
echo "============================================"
echo ""
echo "📋 Monitor:"
echo "   curl -s http://localhost:8038/cgi-bin/tasks/syslog | grep -E 'HASP100|IEF404I|IEF453I' | tail -20"
echo "   TN3270: c3270 localhost:3270 (HERC01/CUL8TR)"
echo ""
