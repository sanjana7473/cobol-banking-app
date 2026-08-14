# COBOL Banking Application — Local vs Oracle Cloud Comparative Analysis

## Goal

Build a Jenkins CI/CD pipeline that:
1. Checks out the COBOL banking application from GitHub
2. Compiles, unit-tests, and integration-tests it
3. Deploys and runs it on **two equivalent environments**:
   - **Environment A** — Local Machine (Hercules + MVS 3.8j/TK5)
   - **Environment B** — Oracle Cloud Always Free VM (Hercules + MVS 3.8j/TK5)
4. Collects results and produces a **Comparative Analysis Report** covering:
   - Build Time
   - Functional Test Fidelity
   - Setup Complexity
   - Cost Analysis

---

## Current State (already built)

- COBOL programs: `VALDTRAN.cbl`, `UPDTBAL.cbl`, `RPRTGEN.cbl`
- Copybook: `cobol/COPYLIB/ACCTREC.cpy` (inlined in programs — not actually `COPY`d)
- Data: `cobol/TRANSIN.DAT` (transactions), `cobol/ACCTMAST.DAT` (account master)
- JCL: `jcl/BANKRUN.jcl` (master job) + one compile/run job per program
- Runner: `run-all.py` (allocates `HERC01.LOAD`, compiles all 3 programs, runs `BANKRUN`, extracts reports)
- Local env scripts: TK5 native (`setup_tk5.sh`, `run_hercules.sh`)
- Golden expected output: `reports/EXPECTED_OUTPUT.txt` (fidelity reference)

---

## Phase 0 — Repo & Code Cleanup

- [ ] Commit and push all source to GitHub (Jenkins can only checkout committed code) — **user action pending**
- [x] Decide `TRANSIN` / `ACCTMAST` naming → **renamed data files** `TRANSACT.DAT`→`TRANSIN.DAT`, `ACCOUNTS.DAT`→`ACCTMAST.DAT` (datasets `HERC01.TRANSIN` / `HERC01.ACCTMAST`)
- [x] Fix data inconsistency → **rewrote both data files as clean 80-byte fixed-width records**; corrected 9-char dates → 8-char; fixed `ACCOUNT-RECORD` filler `X(18)`→`X(20)`; added 3 transactions so all 6 validation codes are exercised
- [x] `ACCTREC.cpy` → kept as reference copybook (filler fixed); programs still inline the layout (defer `COPY` wiring to Phase 2 build)
- [x] Standardize on TK5 → comparison path uses **TK5 native Hercules** (Docker TK4- lab removed)
- [x] Pin expected output → **`reports/EXPECTED_OUTPUT.txt`** (golden): READ=13, VALID=7, INVALID=6 · PROCESSED=7, DEPOSITS=4, WITHDRAWALS=3 · combined balance `$689,200.00` for testing

---

## Phase 1 — CI/CD Pipeline (Jenkins)

- [x] Write `Jenkinsfile` with stages:
  - Checkout → Build/Compile → Unit Test → Integration Test
  - Deploy Env A → Deploy Env B (skipped until Phase 6) → Collect Results
  - Evaluate Metrics → Publish Comparative Analysis Report
- [x] CI helper scripts under `ci/`:
  - `pipeline.py` (`compile`/`run`/`all`/`extract`) — reuses `run-all.py` JCL,
    idempotent via a `RESET` step; returns non-zero on non-zero return codes
  - `compile.sh`, `unit-test.py`+`.sh` (12 checks: layout + all 6 validation-code
    coverage + golden), `integration-test.sh` (golden diff, date-normalized)
  - `deploy-env.sh`, `collect-results.sh`
  - `evaluate-metrics.py`, `generate-report.py` (metrics.json → report.md/.html)
- [x] Configure build triggers (webhook + pollSCM documented in `jenkins/README.md`)
- [x] Capture stage durations (Jenkins `timestamps()` + in-run `*-timing.json`)
- [x] Jenkins provisioning: `jenkins/docker-compose.yml` + `Dockerfile` (plugins) + `README.md`
- [ ] Start Jenkins and add `env-b-ssh` credential (user action — see `jenkins/README.md`)
- [ ] Verify a full pipeline run end-to-end (requires a running mainframe + Jenkins)

---

## Phase 2 — Build/Compile

- [x] Make compilation reproducible and parameterized:
  - `ci/pipeline.py` is the single source of truth for compile/run JCL;
    `run-all.py` now delegates to it (duplicate JCL removed)
  - `ci/compile.sh` is the standalone Build/Compile stage entry
  - Compiler/linker config (`IKFCBL00`, `PARM`, `SYSLIB`) centralized and
    env-overridable, so both environments compile identically
- [x] Log compile return codes (RC=0000) and treat non-zero as pipeline failure
  - `do_compile` snapshots the syslog, logs `IEFACTRT` lines, and returns
    non-zero on any non-zero completion code; `run-all.py` exits non-zero too

---

## Phase 3 — Unit Testing

- [ ] Choose unit-test approach:
  - COBOL test driver per program (assert-style), or
  - GnuCOBOL on Linux for fast logic tests outside the mainframe
- [ ] Define units to test:
  - `VALDTRAN`: validation rules (error codes 01–06)
  - `UPDTBAL`: deposit/withdrawal arithmetic
  - `RPRTGEN`: formatting + status mapping
- [ ] Implement test cases with pass/fail assertions
- [ ] Wire unit tests into the Jenkins "Unit Test" stage (fail pipeline on mismatch)

---

## Phase 4 — Integration Testing

- [ ] Formalize `BANKRUN` as the integration test:
  - Script the run (reuse `run-all.py`)
  - Compare output against the golden expected file (counts + balances)
  - Exit non-zero on any mismatch
- [ ] Add the check to the Jenkins "Integration Test" stage

---

## Phase 5 — Environment A (Local Machine)

- [x] Verify `setup_tk5.sh` + `run_hercules.sh` produce a working TK5 instance
- [x] Confirm ports 3270 / 3505 / 8038 are reachable (Hercules 4.9.1-SDL, MVS 3.8j TK5 booted, JES2 `$HASP000 OK`)
- [x] Add a script to run the pipeline and export reports to a known artifact path (`ci/run-benchmark.sh`)
- [x] Record hardware specs (CPU, RAM, OS) for Cost Analysis — **4 vCPU · 15 GiB RAM · Linux (local system)**

---

## Phase 6 — Environment B (Oracle Cloud Always Free VM)

- [x] Provision an Always Free instance — **Ubuntu 24.04 · 150.136.240.50**
- [x] Install deps (unzip, docker.io) + download/extract TK5 (`setup_tk5.sh`), copy the app + runner
- [x] Open ports 3270 / 3505 / 8038 + SSH (2121 for FTP via pure-ftpd)
- [x] Set up SSH access for Jenkins (key-based, non-interactive)
- [x] Verify `ci/pipeline.py` runs successfully on the VM (14/14 fidelity)
- [x] Record hardware specs for Cost Analysis — **4 vCPU AMD EPYC 9J14 · 7.7 GiB RAM · Ubuntu 24.04**

---

## Benchmark Harness — 14× local vs 14× cloud (FTP)

- [x] **FTP transport**: `ci/pipeline.py` submits JCL via FTP (default `MF_SUBMIT=ftp`,
  `herc01`/`cul8tr` on port 2121) so TK5's `tk5-ftp-watcher.sh` auto-submits to JES2
- [x] **Completion polling + real wall-clock timing** (syslog for compile, printer file for run)
- [x] `ci/benchmark.py` — runs N full compile+run pipelines, records per-run
  compile/run/total seconds, RC, and golden fidelity → `benchmark.json`
- [x] `ci/run-benchmark.sh <A|B> <host>` — runs the benchmark on a target env (local/SSH)
- [x] `ci/compare-benchmarks.py` — side-by-side build-time stats (mean/median/σ/min/max),
  fidelity, verdict → `comparison.json` + `comparison.md`
- [x] Jenkins: `RUN_COUNT` param (default 14) + Benchmark Env A/B stages + Compare stage

Run manually (no Jenkins needed):
```bash
bash ci/run-benchmark.sh A localhost            # 14 runs on local TK5
bash ci/run-benchmark.sh B <oracle-vm-ip> ubuntu # 14 runs on Oracle VM
python3 ci/compare-benchmarks.py                # compare + report
```

---

## Phase 7 — Collect Results

- [x] Machine-readable results format: `benchmark.json` (per-run time, RC, fidelity) + `run-timing.json`
- [x] Collector: `ci/run-benchmark.sh` runs N times per env and pulls `results/env-{a,b}/` back
- [x] Reports stored as pipeline artifacts (`results/**` archived by the Jenkinsfile)

---

## Phase 8 — Evaluation Metrics

- [x] **Build Time**: per-run timers in `benchmark.json`; `compare-benchmarks.py` computes mean/median/σ/min/max
- [x] **Functional Test Fidelity**: date-normalized diff vs golden per run + cross-env equality
- [x] **Setup Complexity**: both environments use the same `setup_tk5.sh` + pure-ftpd + watcher path; only the target differs (localhost vs SSH to the Oracle VM)
- [x] **Cost Analysis**: $0 recurring for both (local hardware already owned; Oracle Always Free tier)

---

## Phase 9 — Comparative Analysis Report

- [x] Report template: `ci/generate-report.py` (summary, per-env results, metrics, conclusion → report.md/.html)
- [x] Auto-generation from collected metrics + benchmark comparison (`comparison.md`)
- [x] Published as Jenkins artifacts (`results/**` archived)

---

## Measured Results — 14× each environment (FTP, full compile + run)

| Metric | Local (Env A) | Oracle Cloud (Env B) |
|---|---|---|
| Total pipeline (mean) | 40.91s | 59.86s |
| Compile (mean) | 6.05s | 21.10s |
| Run (mean) | 3.89s | 8.06s |
| Return code RC=0000 | 14/14 | 14/14 |
| Functional fidelity vs golden | 14/14 | 14/14 |

**Verdict:** both environments produce byte-identical reports across all 28 runs;
Oracle Cloud averages **~19s slower** per pipeline run than local. Full breakdown in
`results/comparison.md` (generated by `ci/compare-benchmarks.py`).

> Note: the first real COBOL runs exposed three latent bugs (VALDTRAN `GO TO`
> early-exit, UPDTBAL nested-`IF` scoping, and report form-feed/banner extraction)
> that the Phase 0 Python simulation had masked. All fixed in commit `d406c58`.

---

## Final Deliverables

- [ ] `Jenkinsfile` + working CI/CD pipeline
- [ ] Unit + integration test suites with pass/fail gates
- [ ] Automated provisioning for Environment B (Oracle Cloud VM)
- [ ] Standardized, identical pipeline on both environments
- [ ] Machine-readable results + auto-generated Comparative Analysis Report
- [ ] Metrics: Build Time, Functional Test Fidelity, Setup Complexity, Cost Analysis
