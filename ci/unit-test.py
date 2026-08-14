#!/usr/bin/env python3
"""Unit tests (Phase 3 placeholder).

Phase 3 will replace this with assert-style COBOL test drivers (GnuCOBOL)
covering VALDTRAN validation rules, UPDTBAL arithmetic, and RPRTGEN formatting.
Until then, this gates the pipeline on deterministic checks of the Phase 0 fixes:

  * Record layout  — TRANSIN.DAT (13 records) and ACCTMAST.DAT (6 records) are
    clean 80-byte fixed-width records with well-formed numeric fields.
  * Coverage       — the sample data exercises all 6 validation error codes.
  * Golden output  — EXPECTED_OUTPUT.txt exists with the expected counts/balance.

Writes results/unit-test.log and results/unit-test.xml (JUnit) and exits
non-zero on any failure.
"""

import os
import sys
import time
import xml.sax.saxutils as saxutils

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
COBOL = os.path.join(ROOT, "cobol")
RESULTS = os.path.join(ROOT, "results")
GOLDEN = os.path.join(ROOT, "reports", "EXPECTED_OUTPUT.txt")

TRANSIN = os.path.join(COBOL, "TRANSIN.DAT")
ACCTMAST = os.path.join(COBOL, "ACCTMAST.DAT")

CASES = []  # list of (name, ok, detail)


def check(name, ok, detail=""):
    CASES.append((name, bool(ok), detail))


def read_lines(path):
    with open(path) as f:
        return [l.rstrip("\n") for l in f]


def is_digits(n):
    return lambda s: len(s) == n and s.isdigit()


# ---------------------------------------------------------------------------
# Structural checks
# ---------------------------------------------------------------------------

def test_structure(rel, expected_count, field_specs):
    path = os.path.join(COBOL, rel)
    try:
        lines = read_lines(path)
    except OSError as e:
        check(f"{rel}:readable", False, str(e))
        return []

    check(f"{rel}:record_count", len(lines) == expected_count,
          f"expected {expected_count}, got {len(lines)}")

    records = []
    for i, line in enumerate(lines, 1):
        if len(line) != 80:
            check(f"{rel}:line{i}_length", False, f"expected 80, got {len(line)}")
            continue
        records.append(line)
        for fname, start, end, predicate in field_specs:
            field = line[start:end]
            if not predicate(field):
                check(f"{rel}:line{i}:{fname}", False, repr(field))
    return records


# ---------------------------------------------------------------------------
# Validation-code coverage checks
# ---------------------------------------------------------------------------

def test_coverage(trans, master):
    """Every validation error code (01-06) must be exercised by the sample data."""
    accts = {m[0:10]: {"status": m[51], "balance": int(m[40:51])} for m in master}

    has_invalid_type = any(t[10] not in "DW" for t in trans)                       # 01
    has_nonexistent = any(t[0:10] not in accts for t in trans)                     # 02
    has_zero_amount = any(int(t[11:20]) == 0 for t in trans)                       # 03
    has_closed = any(t[0:10] in accts and accts[t[0:10]]["status"] == "C"
                     for t in trans)                                                # 04
    has_frozen = any(t[0:10] in accts and accts[t[0:10]]["status"] == "F"
                     for t in trans)                                                # 05
    has_overdraft = any(t[10] == "W" and t[0:10] in accts
                        and int(t[11:20]) > accts[t[0:10]]["balance"]
                        for t in trans)                                             # 06

    # Error codes per VALDTRAN.cbl VALIDATE-TRANSACTION:
    #   01 = account not found, 02 = invalid type, 03 = zero amount,
    #   04 = closed account, 05 = frozen account, 06 = insufficient funds.
    check("coverage:01_nonexistent_account", has_nonexistent)
    check("coverage:02_invalid_type", has_invalid_type)
    check("coverage:03_zero_amount", has_zero_amount)
    check("coverage:04_closed_account", has_closed)
    check("coverage:05_frozen_account", has_frozen)
    check("coverage:06_insufficient_funds", has_overdraft)


def test_golden():
    if not os.path.exists(GOLDEN):
        check("golden:exists", False, GOLDEN)
        return
    joined = "\n".join(read_lines(GOLDEN))
    for needle in ["TOTAL TRANSACTIONS READ:       13",
                   "VALID TRANSACTIONS:             7",
                   "INVALID TRANSACTIONS:           6",
                   "COMBINED TOTAL BALANCE:            $689200.00"]:
        check(f"golden:{needle.split(':')[0].strip()}", needle in joined, needle)


# ---------------------------------------------------------------------------
# JUnit output
# ---------------------------------------------------------------------------

def write_junit(failures, elapsed):
    esc = saxutils.escape
    rows = []
    for name, ok, detail in CASES:
        if ok:
            rows.append(f'    <testcase classname="unit" name="{esc(name)}" time="0.0"/>')
        else:
            rows.append(
                f'    <testcase classname="unit" name="{esc(name)}" time="0.0">\n'
                f'      <failure message="{esc(detail or "failed")}"/>\n'
                f'    </testcase>')
    xml = (f'<?xml version="1.0" encoding="UTF-8"?>\n'
           f'<testsuite name="unit-tests" tests="{len(CASES)}" '
           f'failures="{len(failures)}" errors="0" time="{elapsed}">\n'
           + "\n".join(rows) +
           f'\n</testsuite>\n')
    with open(os.path.join(RESULTS, "unit-test.xml"), "w") as f:
        f.write(xml)


def main():
    t0 = time.time()

    # TRANSIN.DAT layout: acct(10) type(1) amount(9) date(8) desc(30) filler(22)
    trans = test_structure(
        "TRANSIN.DAT", 13,
        [("account", 0, 10, is_digits(10)),
         ("amount", 11, 20, is_digits(9)),
         ("date", 20, 28, is_digits(8))])

    # ACCTMAST.DAT layout: acct(10) name(30) balance(11) status(1) date(8) filler(20)
    master = test_structure(
        "ACCTMAST.DAT", 6,
        [("account", 0, 10, is_digits(10)),
         ("balance", 40, 51, is_digits(11)),
         ("status", 51, 52, lambda s: s in "ACF"),
         ("last_update", 52, 60, is_digits(8))])

    test_coverage(trans, master)
    test_golden()

    failures = [c for c in CASES if not c[1]]
    passed = len(CASES) - len(failures)

    os.makedirs(RESULTS, exist_ok=True)
    with open(os.path.join(RESULTS, "unit-test.log"), "w") as f:
        for name, ok, detail in CASES:
            status = "PASS" if ok else "FAIL"
            f.write(f"{status:4}  {name}" + (f"  ({detail})" if detail else "") + "\n")
        f.write(f"\n{passed} passed, {len(failures)} failed\n")

    write_junit(failures, round(time.time() - t0, 3))

    print(f"Unit Test: {passed} passed, {len(failures)} failed")
    if failures:
        for name, ok, detail in failures:
            print(f"  FAIL {name}" + (f" ({detail})" if detail else ""))
        sys.exit(1)
    return 0


if __name__ == "__main__":
    main()
