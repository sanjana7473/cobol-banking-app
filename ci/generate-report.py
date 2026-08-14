#!/usr/bin/env python3
"""Publish Comparative Analysis Report.

Reads results/metrics.json and the two environment reports and writes:
  results/report.md   - Markdown report
  results/report.html - self-contained HTML report
"""

import html
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RESULTS = os.path.join(ROOT, "results")


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return default


def main():
    metrics_path = os.path.join(RESULTS, "metrics.json")
    if not os.path.exists(metrics_path):
        raise SystemExit("metrics.json not found - run ci/evaluate-metrics.py first")

    with open(metrics_path) as f:
        m = json.load(f)

    report_a = read(os.path.join(RESULTS, "env-a", "report.txt"),
                    "(Environment A report missing)")
    report_b = read(os.path.join(RESULTS, "env-b", "report.txt"),
                    "(Environment B not provisioned yet)")

    md = render_md(m, report_a, report_b)
    with open(os.path.join(RESULTS, "report.md"), "w") as f:
        f.write(md)
    with open(os.path.join(RESULTS, "report.html"), "w") as f:
        f.write(render_html(m, report_a, report_b))

    print("Wrote results/report.md and results/report.html")


def render_md(m, a, b):
    bt = m["build_time"]
    ff = m["functional_fidelity"]
    sc = m["setup_complexity"]
    cost = m["cost_analysis"]
    return "\n".join([
        "# COBOL Banking Application — Comparative Analysis Report\n",
        "## 1. Build Time",
        f"- CI compile: {bt['ci_compile_seconds']} s",
        f"- Integration run: {bt['integration_run_seconds']} s",
        f"- Environment A (local): {bt['env_a']}",
        f"- Environment B (cloud): {bt['env_b']}\n",
        "## 2. Functional Test Fidelity",
        f"- Environment A vs golden: {ff['env_a_vs_golden']}",
        f"- Environment B vs golden: {ff['env_b_vs_golden']}",
        f"- Environment A vs Environment B: {ff['env_a_vs_env_b']}\n",
        "## 3. Setup Complexity",
        f"- Environment A: {sc['env_a']}",
        f"- Environment B: {sc['env_b']}\n",
        "## 4. Cost Analysis",
        f"- Environment A: {cost['env_a']}",
        f"- Environment B: {cost['env_b']}\n",
        "## 5. Environment A Report",
        "```\n" + a + "\n```\n",
        "## 6. Environment B Report",
        "```\n" + b + "\n```\n",
    ])


def render_html(m, a, b):
    def esc(s):
        return html.escape(s)

    bt = m["build_time"]
    ff = m["functional_fidelity"]
    sc = m["setup_complexity"]
    cost = m["cost_analysis"]

    def row(k, v):
        return f"<tr><th>{esc(str(k))}</th><td>{esc(str(v))}</td></tr>"

    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>COBOL Banking — Comparative Analysis Report</title>
<style>
 body {{ font-family: -apple-system, Segoe UI, Roboto, sans-serif; margin: 2rem; color: #1a1a1a; }}
 h1 {{ border-bottom: 2px solid #333; padding-bottom: .4rem; }}
 h2 {{ margin-top: 2rem; }}
 table {{ border-collapse: collapse; margin: .5rem 0 1rem; }}
 th, td {{ border: 1px solid #ccc; padding: .35rem .8rem; text-align: left; }}
 th {{ background: #f2f2f2; }}
 pre {{ background: #f7f7f7; padding: 1rem; overflow-x: auto; font-size: .85rem; }}
</style></head><body>
<h1>COBOL Banking Application — Comparative Analysis Report</h1>

<h2>1. Build Time</h2>
<table>
{row("CI compile (s)", bt["ci_compile_seconds"])}
{row("Integration run (s)", bt["integration_run_seconds"])}
{row("Environment A (local)", bt["env_a"])}
{row("Environment B (cloud)", bt["env_b"])}
</table>

<h2>2. Functional Test Fidelity</h2>
<table>
{row("Environment A vs golden", ff["env_a_vs_golden"])}
{row("Environment B vs golden", ff["env_b_vs_golden"])}
{row("Environment A vs Environment B", ff["env_a_vs_env_b"])}
</table>

<h2>3. Setup Complexity</h2>
<table>
{row("Environment A", sc["env_a"])}
{row("Environment B", sc["env_b"])}
</table>

<h2>4. Cost Analysis</h2>
<table>
{row("Environment A", cost["env_a"])}
{row("Environment B", cost["env_b"])}
</table>

<h2>5. Environment A Report</h2>
<pre>{esc(a)}</pre>

<h2>6. Environment B Report</h2>
<pre>{esc(b)}</pre>
</body></html>
"""


if __name__ == "__main__":
    main()
