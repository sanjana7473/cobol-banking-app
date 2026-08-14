#!/usr/bin/env python3
"""Evaluate Metrics stage.

Reads the collected results and writes results/metrics.json with the four
comparison dimensions from the plan:
  1. Build Time
  2. Functional Test Fidelity (date-normalized report comparison)
  3. Setup Complexity (rubric placeholder — finalised in Phase 8)
  4. Cost Analysis (hardware placeholder — finalised in Phases 5/6)

This stage reports only; the hard functional gate lives in the Integration Test
stage. Exits non-zero only if it cannot produce metrics.json.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pipeline import normalize_report  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RESULTS = os.path.join(ROOT, "results")
GOLDEN = os.path.join(ROOT, "reports", "EXPECTED_OUTPUT.txt")


def read_text(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return None


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def equal(a, b):
    if a is None or b is None:
        return None
    return normalize_report(a) == normalize_report(b)


def main():
    compile_t = read_json(os.path.join(RESULTS, "compile-timing.json")) or {}
    integ_t = read_json(os.path.join(RESULTS, "integration-timing.json")) or {}
    env_a_t = read_json(os.path.join(RESULTS, "env-a", "run-timing.json")) or {}
    env_b_t = read_json(os.path.join(RESULTS, "env-b", "run-timing.json"))

    golden = read_text(GOLDEN)
    report_a = read_text(os.path.join(RESULTS, "env-a", "report.txt"))
    report_b = read_text(os.path.join(RESULTS, "env-b", "report.txt"))

    metrics = {
        "build_time": {
            "ci_compile_seconds": compile_t.get("compile_seconds"),
            "integration_run_seconds": integ_t.get("run_seconds"),
            "env_a": env_a_t,
            "env_b": env_b_t,
        },
        "functional_fidelity": {
            "env_a_vs_golden": equal(report_a, golden),
            "env_b_vs_golden": equal(report_b, golden) if report_b else None,
            "env_a_vs_env_b": equal(report_a, report_b) if report_b else None,
        },
        "setup_complexity": {
            "note": "Phase 8 rubric - fill from provisioning results",
            "env_a": {"scripted": True, "manual_steps": "TBD",
                      "first_run_wall_clock_minutes": None},
            "env_b": {"scripted": True, "manual_steps": "TBD",
                      "first_run_wall_clock_minutes": None},
        },
        "cost_analysis": {
            "env_a": {"type": "local_machine", "cost_usd": 0.0,
                      "hardware": "TBD", "notes": "electricity only"},
            "env_b": {"type": "oracle_cloud_always_free_vm", "cost_usd": 0.0,
                      "hardware": "TBD", "notes": "Always Free tier"},
        },
    }

    hw = read_json(os.path.join(RESULTS, "hardware.json"))
    if hw:
        for k in ("env_a", "env_b"):
            if k in hw:
                metrics["cost_analysis"][k]["hardware"] = hw[k]

    os.makedirs(RESULTS, exist_ok=True)
    out = os.path.join(RESULTS, "metrics.json")
    with open(out, "w") as f:
        json.dump(metrics, f, indent=2)

    print(json.dumps(metrics, indent=2))
    print(f"Metrics written -> {out}")

    if metrics["functional_fidelity"]["env_a_vs_golden"] is False:
        print("WARN: Environment A report differs from golden (see Integration Test)", file=sys.stderr)


if __name__ == "__main__":
    main()
