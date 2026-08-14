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
- Local env scripts: TK4- Docker (`mainframe-ftp-lab/`) and TK5 native (`setup_tk5.sh`, `run_hercules.sh`)
- Sample reports: `reports/ALL_REPORTS.txt`, `reports/ALL_REPORTS_TK5.txt`

---

## Phase 0 — Repo & Code Cleanup

- [ ] Commit and push all source to GitHub (Jenkins can only checkout committed code) — **user action pending**
- [x] Decide `TRANSIN` / `ACCTMAST` naming → **renamed data files** `TRANSACT.DAT`→`TRANSIN.DAT`, `ACCOUNTS.DAT`→`ACCTMAST.DAT` (datasets `HERC01.TRANSIN` / `HERC01.ACCTMAST`)
- [x] Fix data inconsistency → **rewrote both data files as clean 80-byte fixed-width records**; corrected 9-char dates → 8-char; fixed `ACCOUNT-RECORD` filler `X(18)`→`X(20)`; added 3 transactions so all 6 validation codes are exercised
- [x] `ACCTREC.cpy` → kept as reference copybook (filler fixed); programs still inline the layout (defer `COPY` wiring to Phase 2 build)
- [x] Standardize on TK5 → comparison path uses **TK5 native Hercules**; Docker TK4- lab retained as reference only
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

- [ ] Make compilation reproducible and parameterized:
  - Reuse `run-all.py` compile step (or extract a standalone `compile.sh`)
  - Ensure identical compiler (`IKFCBL00`), parms, and JCL on both environments
- [ ] Log compile return codes (RC=0000) and treat non-zero as pipeline failure

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

- [ ] Verify `setup_tk5.sh` + `run_hercules.sh` produce a working TK5 instance
- [ ] Confirm ports 3270 / 3505 / 8038 are reachable
- [ ] Add a script to run the pipeline and export reports to a known artifact path
- [ ] Record hardware specs (CPU, RAM, OS) for Cost Analysis

---

## Phase 6 — Environment B (Oracle Cloud Always Free VM)

- [ ] Create an Oracle Cloud account and provision an Always Free instance
  - Ampere A1 (ARM) or E2.1.Micro (x86)
- [ ] Provision the VM (choose one):
  - Terraform, OCI CLI, or cloud-init script
- [ ] Provisioning script must:
  - Install Hercules + dependencies
  - Download/extract TK5 (`setup_tk5.sh`)
  - Copy the application + runner
  - Open security-list ports 3270 / 3505 / 8038 + SSH
- [ ] Set up SSH access for Jenkins (key-based, non-interactive)
- [ ] Verify `run-all.py` runs successfully on the VM
- [ ] Record hardware specs for Cost Analysis

---

## Phase 7 — Collect Results

- [ ] Define a shared, machine-readable results format (e.g. JSON) exported by both envs:
  - Build time, return codes, report outputs, run timestamps
- [ ] Add a collector step that pulls results from Env A and Env B into Jenkins
- [ ] Store reports as pipeline artifacts for comparison

---

## Phase 8 — Evaluation Metrics

- [ ] **Build Time**: from Jenkins stage durations + in-run timers on each env
- [ ] **Functional Test Fidelity**: script a `diff` of Env A vs Env B reports (byte/field-level equality)
- [ ] **Setup Complexity**: define a rubric and score each env
  - e.g. wall-clock time to first successful run, number of manual steps, scripted vs manual setup
- [ ] **Cost Analysis**: document $0 for both + hardware specs, electricity/notes for local

---

## Phase 9 — Comparative Analysis Report

- [ ] Create a report template (summary, per-env results, metrics table, conclusion)
- [ ] Add a script to auto-generate the report from collected metrics
- [ ] Publish the report as a Jenkins artifact (e.g. HTML/PDF/Markdown)

---

## Final Deliverables

- [ ] `Jenkinsfile` + working CI/CD pipeline
- [ ] Unit + integration test suites with pass/fail gates
- [ ] Automated provisioning for Environment B (Oracle Cloud VM)
- [ ] Standardized, identical pipeline on both environments
- [ ] Machine-readable results + auto-generated Comparative Analysis Report
- [ ] Metrics: Build Time, Functional Test Fidelity, Setup Complexity, Cost Analysis
