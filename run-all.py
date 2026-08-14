#!/usr/bin/env python3
"""COBOL Banking Pipeline — One-Click Runner
   Usage: python3 run-all.py"""

import socket, time, os, subprocess, re

COBOL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cobol")
REPORTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reports")
RAKF = "CLASS=A,USER=HERC01,PASSWORD=CUL8TR"

os.makedirs(REPORTS_DIR, exist_ok=True)


def submit(jcl, label=""):
    data = jcl.encode("ascii")
    s = socket.socket()
    s.settimeout(15)
    s.connect(("127.0.0.1", 3505))
    s.sendall(data)
    time.sleep(0.3)
    s.close()
    print(f"  OK: {label} ({len(data)} bytes)")


def run_docker(cmd_str):
    """Run a command inside the tk4 container via sg docker."""
    full = f"docker exec tk4 {cmd_str}"
    return subprocess.run(["sg", "docker", "-c", full],
                          capture_output=True, text=True, timeout=20)


# ============================================================
print("=" * 50)
print(" COBOL Banking Pipeline")
print("=" * 50)

# -- Step 1: Create HERC01.LOAD --
print("\n[1/5] Creating HERC01.LOAD...")
submit(f"""//ALLOC    JOB (ACCT),'ALLOC',{RAKF}
//STEP     EXEC PGM=IEFBR14
//LOAD     DD DSN=HERC01.LOAD,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(1,1,10)),
//             DCB=(RECFM=U,LRECL=0,BLKSIZE=32760)
//SYSOUT   DD SYSOUT=*
//
""", "ALLOC")
time.sleep(4)

# -- Steps 2-4: Compile all 3 programs --
for pgm in ["VALDTRAN", "UPDTBAL", "RPRTGEN"]:
    print(f"\n[•] Compiling {pgm}...")
    with open(os.path.join(COBOL_DIR, f"{pgm}.cbl")) as f:
        src = f.read()
    jobname = pgm[:4] + "COMP"
    submit(f"""//{jobname} JOB (ACCT),'COMP-{pgm[:4]}',{RAKF}
//COB      EXEC PGM=IKFCBL00,PARM='LOAD,NODECK,SIZE=2048K,BUF=1024K'
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSUT2   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSUT3   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSUT4   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSLIN   DD DSN=&&LOADSET,DISP=(MOD,PASS),
//             UNIT=SYSDA,SPACE=(80,(500,100))
//SYSIN    DD DATA
{src.rstrip()}
/*
//SYSPUNCH DD DUMMY
//LKED     EXEC PGM=IEWL,PARM='LIST,XREF'
//SYSLIB   DD DSN=SYS1.COBLIB,DISP=SHR
//SYSLIN   DD DSN=&&LOADSET,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=HERC01.LOAD({pgm}),DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSPRINT DD SYSOUT=*
//
""", pgm)
    time.sleep(4)

# -- Wait for compiles --
print("\n[•] Waiting for compiles to finish (15s)...")
time.sleep(15)

# -- Step 5: Run BANKRUN (no CLEAN step - DISP=(NEW,CATLG,DELETE) handles both cases) --
print("\n[5/5] Running BANKRUN...")

with open(os.path.join(COBOL_DIR, "TRANSIN.DAT")) as f:
    transact = f.read().rstrip()
with open(os.path.join(COBOL_DIR, "ACCTMAST.DAT")) as f:
    accounts = f.read().rstrip()

submit(f"""//BANKRUN  JOB (ACCT),'BANK-RUN',{RAKF}
//ALLOC    EXEC PGM=IEFBR14
//VALIDATE DD DSN=HERC01.VALIDATE,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//ACCTUPD  DD DSN=HERC01.ACCTUPD,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//SYSOUT   DD SYSOUT=*
//VALD     EXEC PGM=VALDTRAN
//STEPLIB  DD DSN=HERC01.LOAD,DISP=SHR
//TRANSIN DD DATA
{transact}
/*
//VALIDATE DD DSN=HERC01.VALIDATE,DISP=OLD
//VALERR   DD SYSOUT=*
//ACCTMAST DD DATA
{accounts}
/*
//SYSOUT   DD SYSOUT=*
//UPDT     EXEC PGM=UPDTBAL
//STEPLIB  DD DSN=HERC01.LOAD,DISP=SHR
//VALIDATE DD DSN=HERC01.VALIDATE,DISP=OLD
//ACCTMAST DD DATA
{accounts}
/*
//ACCTUPD  DD DSN=HERC01.ACCTUPD,DISP=OLD
//UPDRPT   DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//RPT      EXEC PGM=RPRTGEN
//STEPLIB  DD DSN=HERC01.LOAD,DISP=SHR
//ACCTUPD  DD DSN=HERC01.ACCTUPD,DISP=OLD
//FINALRPT DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//
""", "BANKRUN")

print("\nWaiting 18s for BANKRUN to complete...")
time.sleep(18)

# -- 3. Check return codes --
print("\n" + "=" * 50)
print(" Return Codes")
print("=" * 50)
try:
    import urllib.request
    resp = urllib.request.urlopen("http://localhost:8038/cgi-bin/tasks/syslog")
    html = resp.read().decode("utf-8", errors="replace")
    html = re.sub(r"<[^>]*>", "", html)
    found = False
    for line in html.split("\n"):
        if "IEFACTRT" in line:
            print(line.strip())
            found = True
    if not found:
        print("  (no IEFACTRT lines yet — check syslog manually)")
except Exception as e:
    print(f"  (syslog not available: {e})")

# -- 4. Extract reports from BANKRUN section only --
print("\n" + "=" * 50)
print(" Banking Reports")
print("=" * 50)

path = os.path.join(REPORTS_DIR, "ALL_REPORTS.txt")
try:
    # Find last BANKRUN END marker line number
    r = run_docker("grep -an 'JOB.*BANKRUN.*END' /tk4-/prt/prt00e.txt | tail -1 | cut -d: -f1")
    bank_end = r.stdout.strip()

    if bank_end and bank_end.isdigit():
        start = max(1, int(bank_end) - 100)
        r = run_docker(f"sed -n '{start},{bank_end}p' /tk4-/prt/prt00e.txt")
        raw = r.stdout

        # Filter: keep lines that look like report output (not COBOL source, not JES2 logs)
        lines = raw.split("\n")
        reports = []
        in_report = False
        for line in lines:
            s = line.strip()
            # Detect start of actual report (not COBOL source listing)
            if "TRANSACTION VALIDATION REPORT" in s and "'" not in s:
                in_report = True
            if in_report and s and not s.startswith(("*", "IEF", "$", "\f")):
                # Skip COBOL source listing lines (start with 4-6 digit line number + space)
                if s[0].isdigit():
                    parts = s.split(None, 1)
                    if parts and len(parts[0]) >= 4 and parts[0].isdigit():
                        continue
                reports.append(s)

        if reports:
            with open(path, "w") as f:
                f.write("\n".join(reports))
            print("\n".join(reports))
            print(f"\n  Saved: {path}")
        else:
            print("  No reports in BANKRUN output. Check syslog for errors.")
    else:
        print(f"  BANKRUN output not found. Jobs may still be running.")
except Exception as e:
    print(f"  Could not extract reports: {e}")

print("\n" + "=" * 50)
print(" Done!")
print("=" * 50)
print(" One-click:   bash run-all.sh")
print(" Reports:     reports/ALL_REPORTS.txt")
print(" Connect:     c3270 localhost:3270")
print(" Login:       HERC01 / CUL8TR")
print(" RPF nav:     5 → ST → cursor BANKRUN → S")
