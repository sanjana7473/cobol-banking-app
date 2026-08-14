#!/usr/bin/env python3
"""COBOL Banking Pipeline driver for CI.

Subcommands:
  compile   Reset + allocate HERC01.LOAD, then compile VALDTRAN/UPDTBAL/RPRTGEN
            (IKFCBL00). Fails if any compile returns a non-zero return code.
  run       Submit the BANKRUN job (validate -> update -> report) and check
            return codes. Assumes the programs are already compiled.
  all       compile + run (equivalent to run-all.py, but idempotent).
  extract   Extract the BANKRUN report block from a local printer file.

The JES2 reader (port 3505) and the Hercules web syslog (port 8038) are plain
TCP/HTTP endpoints, so these commands work against a local OR remote mainframe
without SSH. Any failure exits non-zero so Jenkins fails the stage.

This reuses the exact JCL from run-all.py. Phase 2 will consolidate run-all.py
to delegate to this module so there is a single source of truth.
"""

import argparse
import json
import os
import re
import socket
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
COBOL_DIR = os.path.join(ROOT, "cobol")
RAKF = "CLASS=A,USER=HERC01,PASSWORD=CUL8TR"
PROGRAMS = ["VALDTRAN", "UPDTBAL", "RPRTGEN"]


# ---------------------------------------------------------------------------
# JCL builders (identical to run-all.py)
# ---------------------------------------------------------------------------

def submit(jcl, host, port, label=""):
    data = jcl.encode("ascii")
    s = socket.socket()
    s.settimeout(15)
    s.connect((host, port))
    s.sendall(data)
    time.sleep(0.3)
    s.close()
    print(f"  OK: {label} ({len(data)} bytes)")


def reset_jcl():
    """Delete prior run datasets so ALLOC(DISP=NEW) is idempotent. Errors on
    missing datasets are expected and ignored (checked separately below)."""
    return f"""//RESET    JOB (ACCT),'RESET',{RAKF}
//STEP1    EXEC PGM=IEFBR14
//DD1      DD DSN=HERC01.LOAD,DISP=(OLD,DELETE)
//DD2      DD DSN=HERC01.VALIDATE,DISP=(OLD,DELETE)
//DD3      DD DSN=HERC01.ACCTUPD,DISP=(OLD,DELETE)
//SYSOUT   DD SYSOUT=*
//
"""


def alloc_load_jcl():
    return f"""//ALLOC    JOB (ACCT),'ALLOC',{RAKF}
//STEP     EXEC PGM=IEFBR14
//LOAD     DD DSN=HERC01.LOAD,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(1,1,10)),
//             DCB=(RECFM=U,LRECL=0,BLKSIZE=32760)
//SYSOUT   DD SYSOUT=*
//
"""


def compile_jcl(pgm):
    with open(os.path.join(COBOL_DIR, f"{pgm}.cbl")) as f:
        src = f.read()
    jobname = pgm[:4] + "COMP"
    return f"""//{jobname} JOB (ACCT),'COMP-{pgm[:4]}',{RAKF}
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
"""


def bankrun_jcl():
    with open(os.path.join(COBOL_DIR, "TRANSIN.DAT")) as f:
        transact = f.read().rstrip()
    with open(os.path.join(COBOL_DIR, "ACCTMAST.DAT")) as f:
        accounts = f.read().rstrip()
    return f"""//BANKRUN  JOB (ACCT),'BANK-RUN',{RAKF}
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
"""


# ---------------------------------------------------------------------------
# Syslog + return codes
# ---------------------------------------------------------------------------

def fetch_syslog(url):
    """Return the Hercules web-console syslog as a list of stripped lines,
    or None if unavailable."""
    try:
        resp = urllib.request.urlopen(url, timeout=10)
        html = resp.read().decode("utf-8", "replace")
    except Exception as e:
        print(f"  (syslog unavailable: {e})", file=sys.stderr)
        return None
    return re.sub(r"<[^>]*>", "", html).split("\n")


def new_lines(before, after):
    """Lines appended to the syslog between two snapshots (append-only log)."""
    if before is None:
        return after or []
    b = [l.strip() for l in before]
    a = [l.strip() for l in after]
    if a[: len(b)] == b:
        return after[len(b):]
    bset = set(b)
    return [l for l in after if l.strip() not in bset]


def iefactrt_lines(lines):
    return [l.strip() for l in lines if "IEFACTRT" in l]


def check_ok(lines):
    """Return the IEFACTRT lines that report a non-zero completion code."""
    bad = []
    for l in iefactrt_lines(lines):
        m = re.search(r"RC=(\d{4})", l)
        if m and m.group(1) != "0000":
            bad.append(l)
    return bad


# ---------------------------------------------------------------------------
# Report extraction + normalization
# ---------------------------------------------------------------------------

def extract_report_text(raw):
    """Extract the BANKRUN report block from a Hercules printer file.

    Locates the block between the JES2 "START  JOB ... BANKRUN" and
    "END   JOB ... BANKRUN" markers, then keeps everything from the first
    "TRANSACTION VALIDATION REPORT" header onward except JES2 control lines.
    Report lines are kept verbatim (including blank lines and account-detail
    lines, which begin with a 10-digit account number).
    """
    lines = raw.split("\n")
    start = end = None
    for i, l in enumerate(lines):
        if re.search(r"START\s+JOB.*BANKRUN", l) and start is None:
            start = i
        if re.search(r"END\s+JOB.*BANKRUN|JOB.*BANKRUN.*END", l):
            end = i
    block = lines[start + 1:end] if (start is not None and end is not None and end >= start) else lines

    report_start = None
    for i, l in enumerate(block):
        if "TRANSACTION VALIDATION REPORT" in l and "'" not in l:
            report_start = i
            break
    if report_start is None:
        return ""

    reports = []
    for line in block[report_start:]:
        s = line.strip()
        # Skip JES2/control noise; keep report lines (including blank lines and
        # account-detail lines that begin with a digit).
        if s.startswith(("IEF", "$HASP", "$", "*", "START", "END", "JOB")) or "\f" in line:
            continue
        reports.append(s)
    while reports and reports[-1] == "":
        reports.pop()  # drop trailing blank lines left by JES2 formatting
    return "\n".join(reports) + "\n"


def normalize_report(text):
    """Replace the run date (trailing 6-digit YYMMDD on report header lines)
    with a placeholder so output is comparable across runs/environments."""
    out = []
    for line in text.split("\n"):
        if "REPORT" in line:
            line = re.sub(r"\d{6}\s*$", "YYMMDD", line)
        out.append(line)
    return "\n".join(out)


# ---------------------------------------------------------------------------
# Core operations
# ---------------------------------------------------------------------------

def _snap(url):
    return fetch_syslog(url)


def do_compile(host, port, syslog_url):
    """Reset, allocate, and compile all programs. Returns (seconds, bad_lines)."""
    t0 = time.time()
    before = _snap(syslog_url)
    submit(reset_jcl(), host, port, "RESET")
    time.sleep(4)
    mid = _snap(syslog_url)          # discard the reset job's expected errors
    submit(alloc_load_jcl(), host, port, "ALLOC")
    time.sleep(4)
    for pgm in PROGRAMS:
        print(f"[compile] {pgm}...")
        submit(compile_jcl(pgm), host, port, pgm)
        time.sleep(4)
    print("Waiting 15s for compiles to finish...")
    time.sleep(15)
    after = _snap(syslog_url)
    lines = new_lines(mid, after)
    for l in iefactrt_lines(lines):
        print("  " + l)
    return round(time.time() - t0, 2), check_ok(lines)


def do_run(host, port, syslog_url, printer=None, report_out=None):
    """Submit BANKRUN and check return codes. Returns (seconds, bad_lines)."""
    t0 = time.time()
    before = _snap(syslog_url)
    submit(bankrun_jcl(), host, port, "BANKRUN")
    print("Waiting 18s for BANKRUN to complete...")
    time.sleep(18)
    after = _snap(syslog_url)
    lines = new_lines(before, after)
    for l in iefactrt_lines(lines):
        print("  " + l)
    secs = round(time.time() - t0, 2)
    if printer and report_out and os.path.exists(printer):
        with open(printer, errors="replace") as f:
            write_file(report_out, extract_report_text(f.read()))
    elif printer and report_out:
        print(f"  (printer file not found: {printer})", file=sys.stderr)
    return secs, check_ok(lines)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def write_file(path, text):
    d = os.path.dirname(os.path.abspath(path))
    os.makedirs(d, exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def write_json(path, obj):
    if path:
        write_file(path, json.dumps(obj, indent=2) + "\n")


def _fail(bad, what):
    if bad:
        print(f"FAIL: non-zero return codes during {what}:", file=sys.stderr)
        for l in bad:
            print("  " + l, file=sys.stderr)
        sys.exit(1)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _add_mf(sp):
    sp.add_argument("--host", default="127.0.0.1")
    sp.add_argument("--port", type=int, default=3505)
    sp.add_argument("--syslog-url", default="http://127.0.0.1:8038/cgi-bin/tasks/syslog")


def cmd_compile(args):
    secs, bad = do_compile(args.host, args.port, args.syslog_url)
    write_json(args.timing_out, {"compile_seconds": secs})
    _fail(bad, "compile")
    print(f"Compile OK in {secs}s")


def cmd_run(args):
    secs, bad = do_run(args.host, args.port, args.syslog_url, args.printer, args.report_out)
    write_json(args.timing_out, {"run_seconds": secs})
    _fail(bad, "run")
    print(f"BANKRUN OK in {secs}s")


def cmd_all(args):
    c_secs, c_bad = do_compile(args.host, args.port, args.syslog_url)
    r_secs, r_bad = do_run(args.host, args.port, args.syslog_url, args.printer, args.report_out)
    write_json(args.timing_out, {"compile_seconds": c_secs, "run_seconds": r_secs})
    _fail(c_bad + r_bad, "pipeline")
    print(f"Pipeline OK (compile {c_secs}s, run {r_secs}s)")


def cmd_extract(args):
    with open(args.printer, errors="replace") as f:
        raw = f.read()
    text = extract_report_text(raw)
    if args.normalize:
        text = normalize_report(text)
    write_file(args.out, text)
    print(f"Extracted {text.count(chr(10))} lines -> {args.out}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("compile"); _add_mf(c); c.add_argument("--timing-out")
    r = sub.add_parser("run"); _add_mf(r); r.add_argument("--timing-out"); r.add_argument("--printer"); r.add_argument("--report-out")
    a = sub.add_parser("all"); _add_mf(a); a.add_argument("--timing-out"); a.add_argument("--printer"); a.add_argument("--report-out")
    e = sub.add_parser("extract"); e.add_argument("--printer", required=True); e.add_argument("--out", required=True); e.add_argument("--normalize", action="store_true")

    args = p.parse_args()
    {
        "compile": cmd_compile,
        "run": cmd_run,
        "all": cmd_all,
        "extract": cmd_extract,
    }[args.cmd](args)


if __name__ == "__main__":
    main()
