#!/usr/bin/env python3
"""Date-tolerant comparison of two banking report files.

Usage:
  compare-report.py <actual> <golden> [--normalize]

Exits 0 if the reports are equal (after optional run-date normalization),
otherwise prints a unified diff to stdout and exits 1.
"""

import argparse
import difflib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pipeline import normalize_report  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("actual")
    ap.add_argument("golden")
    ap.add_argument("--normalize", action="store_true",
                    help="normalize the run date (YYMMDD) before comparing")
    a = ap.parse_args()

    with open(a.actual) as f:
        actual = f.read()
    with open(a.golden) as f:
        golden = f.read()

    if a.normalize:
        actual = normalize_report(actual)
        golden = normalize_report(golden)

    if actual == golden:
        print("REPORTS MATCH")
        sys.exit(0)

    diff = difflib.unified_diff(
        golden.splitlines(), actual.splitlines(),
        fromfile="golden", tofile="actual", lineterm="")
    sys.stdout.writelines(l + "\n" for l in diff)
    print("REPORTS DIFFER", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main()
