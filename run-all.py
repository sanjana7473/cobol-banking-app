#!/usr/bin/env python3
"""COBOL Banking Pipeline — One-Click Runner.

Thin wrapper over ci/pipeline.py (the single source of truth for the
compile/run JCL). Runs the full pipeline — reset datasets, allocate
HERC01.LOAD, compile VALDTRAN/UPDTBAL/RPRTGEN (IKFCBL00), and execute
BANKRUN — against the mainframe, checks return codes, and writes the extracted
report to reports/ALL_REPORTS.txt.

Usage:
    python3 run-all.py            # or: bash run-all.sh

Environment variables:
    MF_HOST      JES2 reader host (default 127.0.0.1)
    MF_PORT      JES2 reader port (default 3505)
    SYSLOG_URL   Hercules web-console syslog URL
    TK5_PRINTER  printer file path override (default: auto-detect)
    COBOL_COMPILER / COBOL_PARMS / COBOL_SYSLIB / LINKER / LINKER_PARMS
                 compiler/linker tuning (see ci/pipeline.py)
"""

import os
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "ci"))
from pipeline import ROOT, do_compile, do_run  # noqa: E402

HOST = os.environ.get("MF_HOST", "127.0.0.1")
PORT = int(os.environ.get("MF_PORT", "3505"))
SYSLOG_URL = os.environ.get("SYSLOG_URL", "http://127.0.0.1:8038/cgi-bin/tasks/syslog")
REPORTS_DIR = os.path.join(ROOT, "reports")
REPORT_PATH = os.path.join(REPORTS_DIR, "ALL_REPORTS.txt")


def docker_cat(container_path):
    """Dump a file from the TK4 container, trying plain docker then `sg docker`."""
    attempts = (
        ["docker", "exec", "tk4", "cat", container_path],
        ["sg", "docker", "-c", f"docker exec tk4 cat {container_path}"],
    )
    for cmd in attempts:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
            if r.returncode == 0 and r.stdout:
                return r.stdout
        except Exception:
            continue
    return None


def resolve_printer():
    """Return the local path to the Hercules printer file (native TK5 or Docker TK4)."""
    override = os.environ.get("TK5_PRINTER", "")
    if override:
        return override
    native = os.path.join(ROOT, "hercules", "tk5", "prt", "prt00e.txt")
    if os.path.exists(native):
        return native
    dumped = docker_cat("/tk4-/prt/prt00e.txt")
    if dumped:
        tmp = "/tmp/prt00e.txt"
        with open(tmp, "w") as f:
            f.write(dumped)
        return tmp
    return native


def main():
    print("=" * 50)
    print(" COBOL Banking Pipeline")
    print("=" * 50)
    os.makedirs(REPORTS_DIR, exist_ok=True)

    print("\n[1/2] Compiling (reset + allocate + IKFCBL00)...")
    c_secs, c_bad = do_compile(HOST, PORT, SYSLOG_URL)

    print("\n[2/2] Running BANKRUN...")
    r_secs, r_bad = do_run(HOST, PORT, SYSLOG_URL, resolve_printer(), REPORT_PATH)

    bad = c_bad + r_bad
    if bad:
        print("\n" + "=" * 50)
        print(" FAILED — non-zero return codes")
        print("=" * 50)
        for line in bad:
            print("  " + line)
        sys.exit(1)

    print("\n" + "=" * 50)
    print(" Banking Reports")
    print("=" * 50)
    if os.path.exists(REPORT_PATH):
        with open(REPORT_PATH) as f:
            print(f.read())
        print(f"  Saved: {REPORT_PATH}")
    else:
        print("  (report not produced — printer file may not be reachable)")

    print("\n" + "=" * 50)
    print(" Done!")
    print("=" * 50)
    print(f"  Compile {c_secs}s, Run {r_secs}s")
    print("  One-click:   bash run-all.sh")
    print(f"  Reports:     {REPORT_PATH}")
    print("  Connect:     c3270 localhost:3270")
    print("  Login:       HERC01 / CUL8TR")


if __name__ == "__main__":
    main()
