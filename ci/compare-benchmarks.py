#!/usr/bin/env python3
"""Compare benchmark results between Environment A (local) and Environment B (cloud).

Usage:
    compare-benchmarks.py --env-a results/env-a/benchmark.json
                          --env-b results/env-b/benchmark.json
                          --out results/comparison.json
                          --report-out results/comparison.md

Produces:
  * a JSON comparison
  * a Markdown report with side-by-side build-time statistics, fidelity, and
    a short verdict. Environment B is optional (shown as "not run" if missing).
"""

import argparse
import json
import os
import sys


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except OSError as e:
        print(f"  (missing {path}: {e})", file=sys.stderr)
        return None


def fmt_stat(d):
    if not d:
        return "-"
    return (f"mean {d['mean']}s · median {d['median']}s · "
            f"σ {d['stdev']}s · min {d['min']}s · max {d['max']}s")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--env-a", default="results/env-a/benchmark.json")
    ap.add_argument("--env-b", default="results/env-b/benchmark.json")
    ap.add_argument("--out", default="results/comparison.json")
    ap.add_argument("--report-out", default="results/comparison.md")
    args = ap.parse_args()

    ea = load(args.env_a)
    eb = load(args.env_b)
    if not ea:
        sys.exit(1)

    comp = {
        "env_a": {"label": "Local", "file": args.env_a, "summary": ea.get("summary")},
        "env_b": {"label": "Oracle Cloud", "file": args.env_b,
                  "summary": eb.get("summary") if eb else None},
    }

    if eb:
        comp["fidelity"] = {
            "env_a_fidelity": f"{ea['summary']['fidelity_pass_count']}/{ea['runs']}",
            "env_b_fidelity": f"{eb['summary']['fidelity_pass_count']}/{eb['runs']}",
            "env_a_rc_ok": f"{ea['summary']['rc_ok_count']}/{ea['runs']}",
            "env_b_rc_ok": f"{eb['summary']['rc_ok_count']}/{eb['runs']}",
            "reports_identical": (
                ea['summary']['fidelity_pass_count'] == ea['runs']
                and eb['summary']['fidelity_pass_count'] == eb['runs']
                and ea.get('last_report') == eb.get('last_report')
            ),
        }

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(comp, f, indent=2)
    with open(args.report_out, "w") as f:
        f.write(render_md(ea, eb, comp))
    print(f"Wrote {args.out} and {args.report_out}")


def render_md(ea, eb, comp):
    sa = ea["summary"]
    sb = eb["summary"] if eb else None
    L = []
    L.append("# Benchmark Comparison — Local vs Oracle Cloud\n")
    L.append(f"- Runs per environment: **{ea['runs']}** (full compile + run)")
    L.append(f"- Transport: **{ea['transport']}**\n")

    L.append("## Build Time\n")
    L.append("| Metric | Local (Env A) | Oracle Cloud (Env B) |")
    L.append("|---|---|---|")
    for key, label in [("total_seconds", "Total pipeline"), ("compile_seconds", "Compile"), ("run_seconds", "Run")]:
        L.append(f"| {label} | {fmt_stat(sa[key])} | {fmt_stat(sb[key] if sb else None)} |")

    L.append("\n## Functional Test Fidelity\n")
    if sb:
        L.append(f"- Local: {sa['fidelity_pass_count']}/{ea['runs']} reports match golden")
        L.append(f"- Oracle Cloud: {sb['fidelity_pass_count']}/{eb['runs']} reports match golden")
        L.append(f"- RC=0000: Local {sa['rc_ok_count']}/{ea['runs']} · Cloud {sb['rc_ok_count']}/{eb['runs']}")
        L.append(f"- Reports identical across environments: **{comp['fidelity']['reports_identical']}**")
    else:
        L.append("- Oracle Cloud results not present yet (run the benchmark on Environment B).")

    L.append("\n## Verdict\n")
    if sb:
        a_mean = sa["total_seconds"]["mean"]
        b_mean = sb["total_seconds"]["mean"]
        if comp["fidelity"]["reports_identical"]:
            L.append(f"Both environments produce **identical** functional results across all "
                     f"{ea['runs']}+{eb['runs']} runs.")
        delta = b_mean - a_mean
        if delta > 0:
            L.append(f"Oracle Cloud is on average **{round(delta, 2)}s slower** than local "
                     f"per pipeline run ({a_mean}s vs {b_mean}s mean total).")
        elif delta < 0:
            L.append(f"Oracle Cloud is on average **{round(-delta, 2)}s faster** than local "
                     f"per pipeline run ({a_mean}s vs {b_mean}s mean total).")
        else:
            L.append(f"Both environments average **{a_mean}s** total per pipeline run.")
    else:
        L.append("Run the benchmark on Environment B to complete the comparison.")
    return "\n".join(L) + "\n"


if __name__ == "__main__":
    main()
