#!/usr/bin/env python3
"""
COBOL Banking App - Automated Test Script (Pure Python)
Fixed JCL: uses IKFCBL00 + IEWL for compile+link, proper MVS step names.
"""

import socket
import time
import sys
import os

HOST = "localhost"
CARD_PORT = 3505
RAKF = "CLASS=A,USER=HERC01,PASSWORD=CUL8TR"

def submit_jcl(jcl, desc):
    """Submit JCL string via card reader. Handles 'device busy' retries."""
    data = jcl.encode('ascii')
    for attempt in range(3):
        try:
            s = socket.socket()
            s.settimeout(15)
            s.connect((HOST, CARD_PORT))
            s.sendall(data)
            time.sleep(0.3)
            s.close()
            print(f"📤 {desc} ({len(data)} bytes)")
            return True
        except Exception as e:
            print(f"  ⚠️  Attempt {attempt+1}: {e}")
            time.sleep(2)
    print(f"  ❌ Failed after 3 attempts")
    return False

def compile_job(jobname, desc, member):
    """Generate JCL to compile+link a COBOL program using IKFCBL00 + IEWL"""
    return f"""//{jobname:<8} JOB (ACCT),'{desc}',{RAKF}
//COB      EXEC PGM=IKFCBL00,PARM='LOAD,NODECK'
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSUT2   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSUT3   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSUT4   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSLIN   DD DSN=&&LOADSET,DISP=(MOD,PASS),
//             UNIT=SYSDA,SPACE=(80,(500,100))
//SYSIN    DD DSN=HERC01.COBOL({member}),DISP=SHR
//SYSLIB   DD DSN=HERC01.COPYLIB,DISP=SHR
//LKED     EXEC PGM=IEWL,PARM='LIST,XREF'
//SYSLIN   DD DSN=&&LOADSET,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=HERC01.LOAD({member}),DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSPRINT DD SYSOUT=*
//
"""

# =====================================================
# Load source files
# =====================================================
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COBOL_DIR = os.path.join(BASE_DIR, "cobol")

def read_file(path):
    with open(path, 'r') as f:
        return f.read()

valdtran_src = read_file(os.path.join(COBOL_DIR, "VALDTRAN.cbl"))
updtbal_src = read_file(os.path.join(COBOL_DIR, "UPDTBAL.cbl"))
rprtgen_src = read_file(os.path.join(COBOL_DIR, "RPRTGEN.cbl"))
acctrec_src = read_file(os.path.join(COBOL_DIR, "COPYLIB", "ACCTREC.cpy"))
transact_data = read_file(os.path.join(COBOL_DIR, "TRANSIN.DAT"))
accounts_data = read_file(os.path.join(COBOL_DIR, "ACCTMAST.DAT"))

print("=" * 60)
print("🏦 COBOL Banking App - Automated Test (MVS COBOL)")
print("=" * 60)
print(f"   VALDTRAN: {len(valdtran_src)} bytes")
print(f"   UPDTBAL:  {len(updtbal_src)} bytes")
print(f"   RPRTGEN:  {len(rprtgen_src)} bytes")
print(f"   ACCTREC:  {len(acctrec_src)} bytes")
print()

# =====================================================
# Step 0: Cleanup old datasets
# =====================================================
print("--- Step 0: Cleanup ---")
cleanup = f"""//CLEANUP  JOB (ACCT),'CLEANUP',{RAKF}
//STEP     EXEC PGM=IEFBR14
//DD1      DD DSN=HERC01.COBOL,DISP=(OLD,DELETE)
//DD2      DD DSN=HERC01.COPYLIB,DISP=(OLD,DELETE)
//DD3      DD DSN=HERC01.LOAD,DISP=(OLD,DELETE)
//DD4      DD DSN=HERC01.JCL,DISP=(OLD,DELETE)
//DD5      DD DSN=HERC01.TRANSIN,DISP=(OLD,DELETE)
//DD6      DD DSN=HERC01.ACCTMAST,DISP=(OLD,DELETE)
//DD7      DD DSN=HERC01.VALIDATE,DISP=(OLD,DELETE)
//DD8      DD DSN=HERC01.ACCTUPD,DISP=(OLD,DELETE)
//SYSOUT   DD SYSOUT=*
//
"""
submit_jcl(cleanup, "Cleanup")
time.sleep(5)

# =====================================================
# Step 1: Allocate datasets
# =====================================================
print("--- Step 1: Allocate ---")
alloc = f"""//ALLOC    JOB (ACCT),'ALLOC',{RAKF}
//STEP     EXEC PGM=IEFBR14
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
"""
submit_jcl(alloc, "Allocate")
time.sleep(5)

# =====================================================
# Step 2: Populate datasets (IEBUPDTE for PDS members, IEBGENER for sequential data)
# =====================================================
print("--- Step 2: Populate datasets ---")

def iebupdte_job(jobname, desc, dsn, member, content):
    jcl = f"//{jobname:<8} JOB (ACCT),'{desc}',{RAKF}\n"
    jcl += "//STEP     EXEC PGM=IEBUPDTE,PARM=NEW\n"
    jcl += "//SYSPRINT DD SYSOUT=*\n"
    jcl += f"//SYSUT1   DD DSN={dsn},DISP=SHR\n"
    jcl += f"//SYSUT2   DD DSN={dsn},DISP=SHR\n"
    jcl += "//SYSIN    DD DATA\n"
    jcl += f"./ ADD NAME={member}\n"
    jcl += content
    if not content.endswith('\n'):
        jcl += '\n'
    jcl += "./ ENDUP\n"
    jcl += "//\n"
    return jcl

def iebgener_job(jobname, desc, dsn, content):
    jcl = f"//{jobname:<8} JOB (ACCT),'{desc}',{RAKF}\n"
    jcl += "//STEP     EXEC PGM=IEBGENER\n"
    jcl += "//SYSUT1   DD DATA\n"
    jcl += content
    if not content.endswith('\n'):
        jcl += '\n'
    jcl += f"//SYSUT2   DD DSN={dsn},DISP=SHR\n"
    jcl += "//SYSPRINT DD SYSOUT=*\n"
    jcl += "//SYSIN    DD DUMMY\n"
    jcl += "//\n"
    return jcl

population = [
    ("VALDPOP", "POP-VALD", iebupdte_job("VALDPOP", "POP-VALD", "HERC01.COBOL", "VALDTRAN", valdtran_src)),
    ("UPDTPOP", "POP-UPDT", iebupdte_job("UPDTPOP", "POP-UPDT", "HERC01.COBOL", "UPDTBAL", updtbal_src)),
    ("RPTPOP",  "POP-RPRT", iebupdte_job("RPTPOP",  "POP-RPRT", "HERC01.COBOL", "RPRTGEN", rprtgen_src)),
    ("COPYPOP", "POP-COPY", iebupdte_job("COPYPOP", "POP-COPY", "HERC01.COPYLIB", "ACCTREC", acctrec_src)),
    ("TRANPOP", "POP-TRAN", iebgener_job("TRANPOP", "POP-TRAN", "HERC01.TRANSIN", transact_data)),
    ("ACCTPOP", "POP-ACCT", iebgener_job("ACCTPOP", "POP-ACCT", "HERC01.ACCTMAST", accounts_data)),
]

for _, desc, jcl in population:
    submit_jcl(jcl, desc)
    time.sleep(3)

print("  ⏳ Waiting 12s for population...")
time.sleep(12)

# =====================================================
# Step 3: Compile programs (IKFCBL00 + IEWL)
# =====================================================
print("--- Step 3: Compile programs ---")

compile_jobs = [
    ("VALDCOMP", "COMP-VALD", "VALDTRAN"),
    ("UPDTCOMP", "COMP-UPDT", "UPDTBAL"),
    ("RPRTCOMP", "COMP-RPRT", "RPRTGEN"),
]

for jobname, desc, member in compile_jobs:
    jcl = compile_job(jobname, desc, member)
    submit_jcl(jcl, f"Compile {member}")
    time.sleep(5)

print("  ⏳ Waiting 20s for compiles...")
time.sleep(20)

# =====================================================
# Step 4: BANKRUN - the master pipeline
# =====================================================
print("--- Step 4: BANKRUN pipeline ---")

bankrun = f"""//BANKRUN  JOB (ACCT),'BANK-RUN',{RAKF}
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
"""
submit_jcl(bankrun, "BANKRUN")
time.sleep(10)

# =====================================================
# Step 5: Verify output
# =====================================================
print("--- Step 5: Verify ---")
verify = f"""//CHECK    JOB (ACCT),'VERIFY',{RAKF}
//STEP     EXEC PGM=IEBGENER
//SYSUT1   DD DSN=HERC01.LOAD,DISP=SHR
//SYSUT2   DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DUMMY
//
"""
submit_jcl(verify, "Verify LOAD PDS")
time.sleep(5)

print()
print("=" * 60)
print("✅ All jobs submitted!")
print("=" * 60)
print()
print("Monitor: curl -s http://localhost:8038/cgi-bin/tasks/syslog | grep HASP")
print("TN3270:  c3270 localhost:3270 (HERC01/CUL8TR)")
