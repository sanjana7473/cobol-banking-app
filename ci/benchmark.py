#!/usr/bin/env python3
"""Run the COBOL banking pipeline N times and collect per-run metrics.

Usage:
    benchmark.py --runs 14 --env A --out results/env-a/benchmark.json
                 [--host 127.0.0.1] [--port 3505] [--submit ftp]
                 [--syslog-url ...] [--printer ...] [--golden ...]

Each run is a full compile + run (reset -> allocate -> compile -> BANKRUN).
Per-run metrics recorded:
    run             1-based index
    compile_seconds
    run_seconds
    total_seconds   compile + run wall-clock (includes FTP/watcher latency)
    rc_ok           True if no non-zero return code
    fidelity        True if the report matches golden (date-normalized)

Writes a JSON file with per-run details + summary statistics (mean / median /
stdev / min / max). Exits non-zero if any run had a non-zero return code.
"""

import argparse
import json
import os
import statistics
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipeline  # noqa: E402


def resolve_printer(override=""):
    if override:
        return override
    native = os.path.join(pipeline.ROOT, "hercules", "tk5", "prt", "prt00e.txt")
    return native


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--runs", type=int, default=14)
    ap.add_argument("--env", default="A")
    ap.add_argument("--out", default=None, help="output JSON path (required to persist)")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=3505)
    ap.add_argument("--submit", choices=["ftp", "socket"], default=pipeline.SUBMIT_TRANSPORT)
    ap.add_argument("--syslog-url", default="http://127.0.0.1:8038/cgi-bin/tasks/syslog")
    ap.add_argument("--printer", default="")
    ap.add_argument("--golden", default=os.path.join(pipeline.ROOT, "reports", "EXPECTED_OUTPUT.txt"))
    args = ap.parse_args()

    pipeline.SUBMIT_TRANSPORT = args.submit
    printer = resolve_printer(args.printer)
    golden = open(args.golden).read() if os.path.exists(args.golden) else None

    report_tmp = "/tmp/bench_report.txt"
    runs = []
    t_all = time.time()
    for i in range(1, args.runs + 1):
        t0 = time.time()
        print(f"\n===== Run {i}/{args.runs} ({args.env}) =====")
        c_secs, c_bad = pipeline.do_compile(args.host, args.port, args.syslog_url)
        r_secs, r_bad = pipeline.do_run(args.host, args.port, args.syslog_url, printer, report_tmp)
        total = round(time.time() - t0, 2)
        rc_ok = not (c_bad or r_bad)

        report = ""
        if os.path.exists(report_tmp):
            with open(report_tmp) as f:
                report = f.read()
        fidelity = None
        if golden is not None and report:
            fidelity = pipeline.normalize_report(report) == pipeline.normalize_report(golden)

        runs.append({
            "run": i,
            "compile_seconds": c_secs,
            "run_seconds": r_secs,
            "total_seconds": total,
            "rc_ok": rc_ok,
            "fidelity": fidelity,
        })
        print(f"  run {i}: compile={c_secs}s run={r_secs}s total={total}s rc_ok={rc_ok} fidelity={fidelity}")

    summary = build_summary(runs, time.time() - t_all)
    result = {
        "environment": args.env,
        "runs": args.runs,
        "transport": args.submit,
        "runs_detail": runs,
        "summary": summary,
        "last_report": report,
    }

    if args.out:
        pipeline.write_json(args.out, result)
        # Also emit report.txt + run-timing.json (last run) so the existing
        # evaluate-metrics.py / generate-report.py flow keeps working.
        d = os.path.dirname(os.path.abspath(args.out))
        if report:
            pipeline.write_file(os.path.join(d, "report.txt"), report)
        pipeline.write_json(os.path.join(d, "run-timing.json"), {
            "compile_seconds": summary["compile_seconds"]["mean"],
            "run_seconds": summary["run_seconds"]["mean"],
        })
        print(f"\nWrote {args.out}")
    else:
        print(json.dumps(result, indent=2))

    if any(not r["rc_ok"] for r in runs):
        sys.exit(1)
    return 0


def build_summary(runs, total_wall):
    def col(key):
        vals = [r[key] for r in runs]
        return {
            "mean": round(statistics.mean(vals), 3),
            "median": round(statistics.median(vals), 3),
            "stdev": round(statistics.stdev(vals), 3) if len(vals) > 1 else 0.0,
            "min": min(vals),
            "max": max(vals),
        }

    return {
        "total_wall_seconds": round(total_wall, 2),
        "compile_seconds": col("compile_seconds"),
        "run_seconds": col("run_seconds"),
        "total_seconds": col("total_seconds"),
        "rc_ok_count": sum(1 for r in runs if r["rc_ok"]),
        "fidelity_pass_count": sum(1 for r in runs if r["fidelity"]),
    }


if __name__ == "__main__":
    main()
