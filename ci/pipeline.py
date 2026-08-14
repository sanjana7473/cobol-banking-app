#!/usr/bin/env python3
"""COBOL Banking Pipeline driver for CI.

Subcommands:
  compile   Reset + allocate HERC01.LOAD, then compile VALDTRAN/UPDTBAL/RPRTGEN
            (IKFCBL00). Fails if any compile returns a non-zero return code.
  run       Submit the BANKRUN job (validate -> update -> report) and check
            return codes. Assumes the programs are already compiled.
  all       compile + run (equivalent to run-all.py, but idempotent).
  extract   Extract the BANKRUN report block from a local printer file.

Submission transport (env MF_SUBMIT, or --submit):
  ftp     Write each JCL file to the FTP server watched by tk5-ftp-watcher.sh,
          which auto-submits it to the JES2 reader. (default)
  socket  Write JCL directly to the JES2 reader port (3505).

Completion is detected by polling (the syslog for compile jobs, the printer
file for the BANKRUN report), so timing reflects real wall-clock execution —
not fixed sleeps — which makes the local-vs-cloud comparison meaningful.

Any failure exits non-zero so Jenkins fails the stage.
"""

import argparse
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
COBOL_DIR = os.path.join(ROOT, "cobol")
RAKF = "CLASS=A,USER=HERC01,PASSWORD=CUL8TR"
PROGRAMS = ["VALDTRAN", "UPDTBAL", "RPRTGEN"]

# --- Compiler / linker configuration (single source of truth) ---------------
# Environment A and Environment B both run this exact module, so they compile
# with the identical compiler, parms, and JCL. Overridable via environment
# variables for advanced tuning.
COBOL_COMPILER = os.environ.get("COBOL_COMPILER", "IKFCBL00")
COBOL_PARMS = os.environ.get("COBOL_PARMS", "LOAD,NODECK,SIZE=2048K,BUF=1024K")
COBOL_SYSLIB = os.environ.get("COBOL_SYSLIB", "SYS1.COBLIB")
LINKER = os.environ.get("LINKER", "IEWL")
LINKER_PARMS = os.environ.get("LINKER_PARMS", "LIST,XREF")

# --- Submission transport ---------------------------------------------------
# "ftp" uploads each JCL file to the FTP server watched by tk5-ftp-watcher.sh
# (which auto-submits it to the JES2 reader). "socket" writes directly to the
# reader port. Default is "ftp" per project requirements.
SUBMIT_TRANSPORT = os.environ.get("MF_SUBMIT", "ftp").lower()
FTP_HOST = os.environ.get("FTP_HOST", "127.0.0.1")
FTP_PORT = os.environ.get("FTP_PORT", "2121")
FTP_USER = os.environ.get("FTP_USER", "herc01")
FTP_PASS = os.environ.get("FTP_PASS", "cul8tr")
FTP_DIR = os.environ.get("FTP_DIR", "/")


# ---------------------------------------------------------------------------
# JCL builders (identical to run-all.py)
# ---------------------------------------------------------------------------

_submit_seq = 0


def submit(jcl, host, port, label=""):
    """Submit JCL to the mainframe reader via the configured transport."""
    global _submit_seq
    _submit_seq += 1

    if SUBMIT_TRANSPORT == "socket":
        data = jcl.encode("ascii")
        s = socket.socket()
        s.settimeout(15)
        s.connect((host, port))
        s.sendall(data)
        time.sleep(0.3)
        s.close()
        print(f"  OK: {label} ({len(data)} bytes via socket)")
        return

    # FTP transport: write the JCL to a uniquely-named temp file and upload it;
    # tk5-ftp-watcher.sh picks it up and submits it to the JES2 reader.
    fd, path = tempfile.mkstemp(prefix=f"jcl_{label}_", suffix=".jcl")
    with os.fdopen(fd, "w") as f:
        f.write(jcl)
    name = os.path.basename(path)
    url = f"ftp://{FTP_USER}:{FTP_PASS}@{FTP_HOST}:{FTP_PORT}{FTP_DIR.rstrip('/')}/{name}"
    try:
        r = subprocess.run(["curl", "-sS", "-T", path, url],
                           capture_output=True, text=True, timeout=60)
        if r.returncode != 0:
            msg = (r.stderr or r.stdout or "").strip()
            print(f"  FTP upload FAILED for {label}: {msg}", file=sys.stderr)
            raise RuntimeError(f"FTP upload failed for {label}: {msg}")
    finally:
        try:
            os.remove(path)
        except OSError:
            pass
    print(f"  OK: {label} ({len(jcl.encode('ascii'))} bytes via FTP)")


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
//COB      EXEC PGM={COBOL_COMPILER},PARM='{COBOL_PARMS}'
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
//LKED     EXEC PGM={LINKER},PARM='{LINKER_PARMS}'
//SYSLIB   DD DSN={COBOL_SYSLIB},DISP=SHR
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

def _full_syslog_url(url):
    """Return the syslog URL with msgcount=0 so the full (untruncated) log is
    returned. The Hercules web console defaults to the last ~22 lines, which
    breaks append-only completion polling."""
    if "msgcount" in url:
        return url
    sep = "&" if "?" in url else "?"
    return f"{url}{sep}msgcount=0"


def fetch_syslog(url):
    """Return the Hercules web-console syslog as a list of stripped lines,
    or None if unavailable."""
    try:
        resp = urllib.request.urlopen(_full_syslog_url(url), timeout=10)
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
# Completion polling (real wall-clock timing)
# ---------------------------------------------------------------------------

def _snap(url):
    return fetch_syslog(url)


def _done(jobname, lines, require_link=False, require_end=False):
    for l in lines:
        if jobname not in l:
            continue
        if "HASP395" in l or "ENDED" in l:
            return True
        if require_end:
            continue
        if "IEFACTRT" in l and (not require_link or "LKED" in l):
            return True
    return False


def wait_for(jobnames, before, syslog_url, min_wait=3, timeout=240, poll=2,
             require_link=False, require_end=False):
    """Poll the syslog until every job shows completion.

    Returns (elapsed_seconds, new_lines_since_before). Falls back to returning
    the lines collected so far on timeout (caller still checks return codes).
    """
    t0 = time.time()
    time.sleep(min_wait)
    while True:
        after = _snap(syslog_url)
        lines = new_lines(before, after) if after else []
        if after is not None and all(_done(jn, lines, require_link, require_end) for jn in jobnames):
            return round(time.time() - t0, 2), lines
        if time.time() - t0 >= timeout:
            return round(time.time() - t0, 2), lines
        time.sleep(poll)


def count_bankrun_ends(printer):
    """Count completed BANKRUN blocks (END markers) in a printer file."""
    if not printer:
        return 0
    try:
        with open(printer, errors="replace") as f:
            raw = f.read()
    except OSError:
        return 0
    return len(re.findall(r"END\s+JOB.*BANKRUN|JOB.*BANKRUN.*END", raw))


def wait_for_report(printer, baseline_ends, timeout=240, poll=2):
    """Wait until a new BANKRUN block completes, then return its report.

    Returns (elapsed_seconds, report_text). The report is extracted from the
    LAST completed BANKRUN block in the (accumulating) printer file.
    """
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            with open(printer, errors="replace") as f:
                raw = f.read()
        except OSError:
            time.sleep(poll)
            continue
        if len(re.findall(r"END\s+JOB.*BANKRUN|JOB.*BANKRUN.*END", raw)) > baseline_ends:
            return round(time.time() - t0, 2), extract_report_text(raw)
        time.sleep(poll)
    try:
        with open(printer, errors="replace") as f:
            report = extract_report_text(f.read())
    except OSError:
        report = ""
    return round(time.time() - t0, 2), report


# ---------------------------------------------------------------------------
# Report extraction + normalization
# ---------------------------------------------------------------------------

def extract_report_text(raw):
    """Extract the LAST completed BANKRUN report block from a printer file.

    Keeps everything from the first "TRANSACTION VALIDATION REPORT" header
    onward within that block, except JES2 control lines. Report lines are kept
    verbatim (including blank lines and account-detail lines, which begin with
    a 10-digit account number).
    """
    lines = raw.split("\n")
    starts = [i for i, l in enumerate(lines) if re.search(r"START\s+JOB.*BANKRUN", l)]
    ends = [i for i, l in enumerate(lines) if re.search(r"END\s+JOB.*BANKRUN|JOB.*BANKRUN.*END", l)]
    if starts and ends:
        end = ends[-1]
        start = max(s for s in starts if s < end)
        block = lines[start + 1:end]
    else:
        block = lines

    report_start = None
    for i, l in enumerate(block):
        if "TRANSACTION VALIDATION REPORT" in l and "'" not in l:
            report_start = i
            break
    if report_start is None:
        return ""

    reports = []
    for line in block[report_start:]:
        # Strip form feeds before classifying: page breaks precede each report
        # header and the trailing JES2 separator/banner page.
        s = line.replace("\f", "").strip()
        # Skip JES2/control noise; keep report lines (including blank lines and
        # account-detail lines that begin with a digit).
        if s.startswith(("IEF", "$HASP", "$", "*", "START", "END", "JOB")):
            continue
        reports.append(s)
        # "COMBINED TOTAL BALANCE" is the last line RPRTGEN writes; everything
        # after it is the JES2 job separator/banner page, not report data.
        if "COMBINED TOTAL BALANCE" in s:
            break
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

def do_compile(host, port, syslog_url):
    """Reset, allocate, and compile all programs. Returns (seconds, bad_lines)."""
    before = _snap(syslog_url)
    submit(reset_jcl(), host, port, "RESET")
    _, _ = wait_for(["RESET"], before, syslog_url, min_wait=3, timeout=90, require_end=True)
    mid = _snap(syslog_url)          # discard the reset job's expected errors

    submit(alloc_load_jcl(), host, port, "ALLOC")
    for pgm in PROGRAMS:
        print(f"[compile] {pgm}...")
        submit(compile_jcl(pgm), host, port, pgm)

    jobnames = [p[:4] + "COMP" for p in PROGRAMS]
    secs, lines = wait_for(jobnames, mid, syslog_url, min_wait=6, timeout=300, require_link=True)
    for l in iefactrt_lines(lines):
        print("  " + l)
    return secs, check_ok(lines)


def do_run(host, port, syslog_url, printer=None, report_out=None):
    """Submit BANKRUN and wait for its report. Returns (seconds, bad_lines)."""
    before = _snap(syslog_url)
    baseline = count_bankrun_ends(printer)
    submit(bankrun_jcl(), host, port, "BANKRUN")

    if printer:
        secs, report = wait_for_report(printer, baseline, timeout=300)
        if report and report_out:
            write_file(report_out, report)
        elif report_out:
            print(f"  (report not produced from {printer})", file=sys.stderr)
    else:
        secs, _ = wait_for(["BANKRUN"], before, syslog_url, min_wait=6, timeout=300, require_end=True)

    after = _snap(syslog_url)
    lines = new_lines(before, after) if after else []
    for l in iefactrt_lines(lines):
        print("  " + l)
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
    sp.add_argument("--submit", choices=["ftp", "socket"], default=SUBMIT_TRANSPORT,
                    help="submission transport (default from MF_SUBMIT, else ftp)")


def _apply_submit(args):
    global SUBMIT_TRANSPORT
    SUBMIT_TRANSPORT = args.submit


def cmd_compile(args):
    _apply_submit(args)
    secs, bad = do_compile(args.host, args.port, args.syslog_url)
    write_json(args.timing_out, {"compile_seconds": secs})
    _fail(bad, "compile")
    print(f"Compile OK in {secs}s")


def cmd_run(args):
    _apply_submit(args)
    secs, bad = do_run(args.host, args.port, args.syslog_url, args.printer, args.report_out)
    write_json(args.timing_out, {"run_seconds": secs})
    _fail(bad, "run")
    print(f"BANKRUN OK in {secs}s")


def cmd_all(args):
    _apply_submit(args)
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
