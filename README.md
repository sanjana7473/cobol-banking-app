# COBOL Banking Application — MVS 3.8j (TK5) + Jenkins CI/CD

A COBOL banking application (validate → update → report) compiled and run on
**MVS 3.8j** under the **Hercules** emulator (Turnkey 5), driven end-to-end over
FTP, with a Jenkins CI/CD pipeline and a local-vs-Oracle-Cloud comparative
benchmark.

## Application

| Program    | Role |
|------------|------|
| `VALDTRAN` | Validate transactions. 6 error codes: `01` non-existent account, `02` invalid type, `03` zero amount, `04` closed account, `05` frozen account, `06` insufficient funds |
| `UPDTBAL`  | Apply valid deposits/withdrawals to account balances |
| `RPRTGEN`  | Generate the balance report and totals |

Pipeline flow:

```
TRANSIN + ACCTMAST → VALDTRAN → VALIDATE (+ error report)
VALIDATE + ACCTMAST → UPDTBAL  → ACCTUPD (+ update report)
ACCTUPD             → RPRTGEN  → FINALRPT (balances + totals)
```

## Directory Structure

```
.
├── cobol/                    # COBOL source + data
│   ├── COPYLIB/ACCTREC.cpy   # copybook (reference)
│   ├── VALDTRAN.cbl          # transaction validation
│   ├── UPDTBAL.cbl           # balance update
│   ├── RPRTGEN.cbl           # report generation
│   ├── TRANSIN.DAT           # sample transactions (13 records, 80-byte)
│   └── ACCTMAST.DAT          # sample account master (6 accounts, 80-byte)
├── jcl/                      # MVS JCL jobs (one compile/run job per program + BANKRUN)
├── ci/                       # CI/CD stage scripts (one per Jenkins stage)
│   ├── pipeline.py           # compile/run/extract driver (single source of truth)
│   ├── benchmark.py          # run N full pipelines, collect per-run metrics
│   ├── compare-benchmarks.py # side-by-side env comparison + verdict
│   └── ...                   # compile/unit/integration/deploy/collect/evaluate/report
├── jenkins/                  # Jenkins master provisioning (docker-compose + plugins)
├── reports/
│   ├── EXPECTED_OUTPUT.txt   # golden expected output (fidelity reference)
├── Jenkinsfile               # CI/CD pipeline definition
├── setup_tk5.sh              # download + extract MVS 3.8j TK5
├── run_hercules.sh           # boot TK5 under Hercules
├── tk5-ftp-watcher.sh        # watch FTP uploads → auto-submit to JES2
├── run-all.py / run-all.sh   # one-shot runner (reset → compile → BANKRUN)
├── comparison results.txt    # 14× local vs 14× Oracle Cloud benchmark results
├── plan.md                   # implementation plan (phases 0–9)
└── README.md
```

## Prerequisites

- Linux with `python3`, `wget`, `unzip`, `curl`, `docker`
- The TK5 Hercules binary is bundled by `setup_tk5.sh` (no system Hercules required)

## Quick Start

### 1. Install TK5

```bash
bash setup_tk5.sh        # downloads + extracts MVS 3.8j TK5 into hercules/tk5/
```

### 2. Boot TK5

```bash
bash run_hercules.sh
# wait ~60–90s for IPL; verify:
curl -s "http://127.0.0.1:8038/cgi-bin/tasks/syslog" | grep -a 'HASP000 OK'
```

Headless (non-interactive) boot, as used by the benchmark:

```bash
cd hercules/tk5
export LD_LIBRARY_PATH="$PWD/hercules/linux/64/lib:$PWD/hercules/linux/64/lib/hercules"
tail -f /dev/null | ./hercules/linux/64/bin/hercules -f conf/tk5.cnf -r scripts/ipl.rc > log/3033.log 2>&1 &
```

### 3. Start the FTP server + watcher

```bash
# pure-ftpd (uploads land in hercules/tk5/rdr/)
docker run -d --name pure-ftpd \
  -p 2121:21 -p 30000-30009:30000-30009 \
  -e FTP_USER_NAME=herc01 -e FTP_USER_PASS=cul8tr \
  -e FTP_USER_HOME=/home/ftpusers/herc01 \
  -e PUBLICHOST=127.0.0.1 \
  -v "$PWD/hercules/tk5/rdr:/home/ftpusers/herc01" \
  stilliard/pure-ftpd:latest

# watcher: polls rdr/ and submits each uploaded file to JES2 (port 3505)
bash tk5-ftp-watcher.sh
```

### 4. Run the pipeline

```bash
bash run-all.sh
# or, with explicit FTP target:
MF_SUBMIT=ftp FTP_HOST=127.0.0.1 FTP_PORT=2121 FTP_USER=herc01 FTP_PASS=cul8tr \
  python3 ci/pipeline.py all \
    --host 127.0.0.1 --port 3505 \
    --syslog-url http://127.0.0.1:8038/cgi-bin/tasks/syslog \
    --printer hercules/tk5/prt/prt00e.txt
```

Expected result: READ=13, VALID=7, INVALID=6 · PROCESSED=7, DEPOSITS=4,
WITHDRAWALS=3 · combined balance `$689,200.00` (matches
`reports/EXPECTED_OUTPUT.txt`).

## Data File Formats (80-byte fixed-width)

```
TRANSIN.DAT
 1-10  Account        9(10)
 11    Type           X(01)  D/W
 12-20 Amount         9(07)V99
 21-28 Date           9(08)
 29-58 Description    X(30)
 59-80 filler         X(22)

ACCTMAST.DAT
 1-10  Account        9(10)
 11-40 Holder name    X(30)
 41-51 Balance        9(09)V99
 52    Status         X(01)  A/C/F
 53-60 Last update    9(08)
 61-80 filler         X(20)
```

## CI/CD Pipeline (Jenkins)

A declarative [`Jenkinsfile`](Jenkinsfile) implements:

```
Checkout → Build/Compile → Unit Test → Integration Test
        → Benchmark Env A (14×) → Benchmark Env B (14×)
        → Compare & Evaluate → Publish Report
```

- **Submission via FTP** (default): each JCL file is uploaded to the FTP server
  watched by `tk5-ftp-watcher.sh`, which auto-submits it to TK5's JES2 reader
  (`MF_SUBMIT=ftp`, `herc01`/`cul8tr` on port 2121).
- Stage scripts live in [`ci/`](ci/); the driver is `ci/pipeline.py`.
- **Unit tests** (12 checks) cover the 80-byte layouts, all 6 validation codes,
  and the golden output — `ci/unit-test.py`.
- **Integration test** runs `BANKRUN` and diffs against
  `reports/EXPECTED_OUTPUT.txt` (date-normalized).

Provision Jenkins and configure credentials/webhooks — see
[`jenkins/README.md`](jenkins/README.md).

## Benchmark — 14× local vs 14× Oracle Cloud

Run the full compile+run pipeline 14 times per environment and compare:

```bash
bash ci/run-benchmark.sh A localhost              # 14 runs on local TK5
bash ci/run-benchmark.sh B <oracle-vm-ip> ubuntu  # 14 runs on Oracle VM
python3 ci/compare-benchmarks.py                  # comparison + report
```

Results are summarized in [`comparison results.txt`](comparison results.txt).

## Credentials

| System | User | Password |
|--------|------|----------|
| MVS / TSO | `HERC01` | `CUL8TR` |
| FTP | `herc01` | `cul8tr` |

## Stop

```bash
docker stop pure-ftpd        # stop the FTP server
# stop Hercules from its console: /s (shutdown), or kill the hercules process
```

## Troubleshooting

```bash
# Hercules console log
tail -f hercules/tk5/log/3033.log

# Web console (syslog)
curl -s "http://127.0.0.1:8038/cgi-bin/tasks/syslog?msgcount=0"

# FTP
docker logs pure-ftpd --tail 20
curl -l ftp://herc01:cul8tr@127.0.0.1:2121/

# Watcher
tail -f hercules/tk5/ftp-watcher.log
```
