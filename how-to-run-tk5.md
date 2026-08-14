# How to Run — TK5 (Native Hercules)

> All commands run from `/home/ubuntu`

## 1. Start TK5 Hercules

```bash
cd "/home/ubuntu/Meshach Cobol Code_Cobol Code/hercules/tk5"

# Set environment
export PATH="$(pwd)/hercules/linux/64/bin:$PATH"
export LD_LIBRARY_PATH="$(pwd)/hercules/linux/64/lib:$(pwd)/hercules/linux/64/lib/hercules:$LD_LIBRARY_PATH"
export HERCULES_RC=scripts/ipl.rc

# Start Hercules in background
nohup hercules/linux/64/bin/hercules -d -f conf/tk5.cnf > log/3033.log 2>&1 &

# Wait for IPL (ports 3270, 3505, 8038)
# Check: ss -tlnp | grep -E "3270|3505|8038"
```

Wait ~60 seconds for MVS to finish IPL. Verify:

```bash
curl -s http://localhost:8038/cgi-bin/tasks/syslog | sed 's/<[^>]*>//g' | grep "HASP000 OK"
```

## 2. Run the Pipeline

First, verify TK5 is ready (must show `$HASP000 OK`):

```bash
curl -s http://localhost:8038/cgi-bin/tasks/syslog | sed 's/<[^>]*>//g' | grep "HASP000 OK"
```

Then run:

```bash
cd "/home/ubuntu/Cobol Code Final"
python3 run-all.py
```

The jobs submit via port 3505 to TK5. All 5 jobs (ALLOC, 3 compiles, BANKRUN) should complete with **RC=0000**.

Quick check:

```bash
curl -s http://localhost:8038/cgi-bin/tasks/syslog | sed 's/<[^>]*>//g' | grep IEF404I
```

Reports are saved to the TK5 printer file:

```bash
cat "/home/ubuntu/Meshach Cobol Code_Cobol Code/hercules/tk5/prt/prt00e.txt" | grep -a "VALIDATION REPORT\|UPDATE REPORT\|BALANCE REPORT"
```

## 3. View Reports via c3270

### Connect

```bash
c3270 localhost:3270
```

### Login

TK5 shows the **MVS 3.8j Tur(n)key** splash screen with `Logon ===>`.

Type `HERC01` → **Enter** → `CUL8TR` → **Enter**

### ISPF Primary Option Menu

After login, TK5 shows the **ISPF v2.2** menu:

```
                         ISPF primary option menu

Option  ===>

   0  ISPF PARMS    Specify terminal and user parms
   1  BROWSE        Display source data using Review
   2  EDIT          Change source data using Revedit
   R  RPF           Browse, EDIT, Reset, PDS with RPF
   3  UTILITIES     Perform utility functions
   4  FOREGROUND    Invoke language processors
   5  BATCH         Submit job for language processing
   6  COMMAND       Enter TSO command or CLIST
   7  DIALOG TEST   Perform dialog testing
   C  CHANGES       Summary of changes for this release
   M  TSOAPPLS      Productivity tools and handy apps
   T  TUTORIAL      Display information about ISPF
   T1 TK5           Summary of changes made in TK5
   X  EXIT          Terminate ISPF using log and list defaults
```

### RPF Main Menu (after PF3 past RPFED)

```
------------------------------ RPF Main menu ------------ (C)-1979-2026 Skybird

Option  ===>

  0  DEFAULTS    Alter / Display session defaults
  1  BROWSE      View or browse data sets or members
  2  EDIT        Update or create data sets or members
  3  UTILITY     Enter UTILITY
  4  ASSEMBLER   Foreground ASSEMBLER and LINK edit
  5  USER        Execute RPF user routine
  6  TSO         Execute TSO commands
  7  TUTORIAL    Display HELP information
  8  TEST        Enter TEST mode (Authorized)
  9  OPERATOR    Enter OPERATOR mode
  X  EXIT        Terminate RPF
```

### RPF Utility Menu (option 3 from RPF Main)

```
------------------------------ RPF Utility menu ------------------------------

Option  ===>

  0  RESET         Reset/Delete ISPF/RPF statistics
  1  LIBRARY       Library (PDS) Functions
  2  DATA SET      Create or Delete data sets
  3  MOVE/COPY     Move or copy data sets or members
  4  DS LIST       Perform VTOC and catalog functions
  5  LIBRARIAN     Perform LIBRARIAN maintenance
  6  OUTPUT        Invoke the output processor
  7  IMON          Interactive monitor of Greg Price
  8  SEARCH        Search data sets for strings of data
  9  ARCHIVER      Process archived members
  X  EXIT          Return to MAIN menu
```

### RPF Output Processor (option 6 from Utility)

```
RPF Output processor, User ID = HERC01  -------------------------------

Option =>

  L     List job status
  D     Purge output (delete)
  P     Print output to a data set
  R     Re-queue output
  blank Browse/View output


  Jobname ===> HERC01         Jobid   ===>            Class   ===> A
```

> **Note:** `L` only shows active/unpurged jobs. BANKRUN completes in seconds and gets purged. You must view it **immediately after** running the pipeline, or use the command-line method (Section 4) which reads the printer file directly.

### Navigate to Job Output (ISPF → R → PF3 → 3 → 6 → L)

**⚠️ Important:** Run the pipeline first, then immediately follow these steps before jobs get purged:

```
Step 1: Type R → Enter          (RPFED entry panel)
Step 2: PF3 (Esc+3)             (exit RPFED → RPF Main Menu)
Step 3: Type 3 → Enter          (RPF Utility menu)
Step 4: Type 6 → Enter          (OUTPUT — output processor)
Step 5: Type L → Enter          (List job status — shows HERC01 jobs)
Step 6: Cursor to BANKRUN, leave Option blank → Enter  (Browse/View)
Step 7: PF7/PF8 to scroll       (up/down through reports)
Step 8: PF3 to go back          (repeat to return to ISPF)
```

> **Quick path:** `=R` → `PF3` → `3` → `6` → `L` → cursor BANKRUN → `Enter`
>
> **If BANKRUN is already purged**, use the **two-terminal approach**:
> ```
> Terminal 1: c3270 → navigate to OUTPUT screen (steps 1-4)
>             Type L but DON'T press Enter yet
> Terminal 2: python3 run-all.py
> Terminal 1: Press Enter the moment the pipeline finishes
> ```
>
> **Easiest:** Use the command line (Section 4) — the printer file keeps all output permanently, no timing issues.

### c3270 Keyboard Shortcuts

| 3270 Key | Mapping | Action |
|----------|---------|--------|
| Enter | `Enter` or `Ctrl+M` | Submit |
| PF1–PF12 | `Esc` + `1`–`9`, `0`, `-`, `=` | Function keys |
| PF3 | `Esc` + `3` | End / Go Back |
| PF7 | `Esc` + `7` | Scroll Up |
| PF8 | `Esc` + `8` | Scroll Down |
| Clear | `Ctrl+L` | Clear screen |
| Quit | `Ctrl+C` | Disconnect |

### What You Should See (BANKRUN Output)

```
TRANSACTION VALIDATION REPORT                260729

VALIDATION SUMMARY

TOTAL TRANSACTIONS READ:       13
VALID TRANSACTIONS:             7
INVALID TRANSACTIONS:           6

ACCOUNT UPDATE REPORT                        260729

UPDATE SUMMARY

TOTAL TRANSACTIONS PROCESSED:       7
DEPOSITS PROCESSED:                 4
WITHDRAWALS PROCESSED:              3

BANK ACCOUNT BALANCE REPORT                       260729

ACCOUNT     HOLDER NAME                     BALANCE        STATUS
--------------------------------------------------------------------------------
1000000001  John Smith                        $50300.00  ACTIVE
1000000002  Jane Doe                         $125800.00  ACTIVE
1000000003  Robert Johnson                     $2550.00  ACTIVE
1000000004  Alice Williams                      $550.00  ACTIVE
1000000005  Closed Account                    $10000.00  CLOSED
1000000006  Frozen Account                   $500000.00  FROZEN

================================================================================
TOTAL ACCOUNTS REPORTED:            6
COMBINED TOTAL BALANCE:            $689200.00
```

## 4. View Reports via Command Line

```bash
# Full printer output
cat "/home/ubuntu/Meshach Cobol Code_Cobol Code/hercules/tk5/prt/prt00e.txt"

# Extract BANKRUN output only
PRT="/home/ubuntu/Meshach Cobol Code_Cobol Code/hercules/tk5/prt/prt00e.txt"
START=$(grep -an "START  JOB.*BANKRUN" "$PRT" | tail -1 | cut -d: -f1)
END=$(grep -an "END   JOB.*BANKRUN" "$PRT" | tail -1 | cut -d: -f1)
sed -n "${START},${END}p" "$PRT"

# Golden expected output
cat "/home/ubuntu/Cobol Code Final/reports/EXPECTED_OUTPUT.txt"
```

## 5. Stop TK5

```bash
# Find and kill Hercules
ps aux | grep hercules | grep -v grep
pkill -9 -f hercules

# Verify all ports are clear
ss -tlnp | grep -E "3270|3505|8038"
# (should be empty)
```

## 6. FTP Upload (Optional)

TK5 doesn't include FTP by default. To add FTP for uploading JCL directly:

### One-Time Setup

```bash
# 1. Start FTP Docker container
sg docker -c "docker run -d --name tk5-ftp \
  -p 2121:21 \
  -p 30000-30009:30000-30009 \
  -v '/home/ubuntu/Meshach Cobol Code_Cobol Code/hercules/tk5/rdr:/home/ftpuser/jcl' \
  -e FTP_USER_NAME=herc01 \
  -e FTP_USER_PASS=cul8tr \
  -e FTP_USER_HOME=/home/ftpuser/jcl \
  stilliard/pure-ftpd"

# 2. Start the FTP watcher (sends uploaded files to TK5)
cd "/home/ubuntu/Cobol Code Final"
nohup bash tk5-ftp-watcher.sh > /tmp/tk5-ftp-watcher.log 2>&1 &
```

### Upload JCL via FTP

```bash
# Using curl
curl -T myjob.jcl ftp://localhost:2121/ --user herc01:cul8tr

# Using ftp command
ftp localhost 2121
# user: herc01
# pass: cul8tr
# put myjob.jcl
```

Uploaded files are automatically submitted to TK5's JES2 reader (port 3505).

### Stop FTP

```bash
sg docker -c "docker stop tk5-ftp && docker rm tk5-ftp"
pkill -f tk5-ftp-watcher
```

## 7. Benchmark — 14× runs + comparison

Run the full pipeline (reset → compile → BANKRUN) **14 times** on local TK5 and
**14 times** on the Oracle VM, then compare build time and fidelity.

```bash
# On the local machine (Environment A) — or from Jenkins
bash ci/run-benchmark.sh A localhost

# Against the Oracle VM (Environment B)
bash ci/run-benchmark.sh B <oracle-vm-ip> ubuntu

# Compare the two and produce the report
python3 ci/compare-benchmarks.py
cat results/comparison.md
```

Config via env vars:

| Variable | Default | Purpose |
|----------|---------|---------|
| `RUN_COUNT` | `14` | runs per environment |
| `MF_SUBMIT` | `ftp` | `ftp` (watcher) or `socket` (port 3505) |
| `FTP_HOST` / `FTP_PORT` | `127.0.0.1` / `2121` | FTP server |
| `FTP_USER` / `FTP_PASS` | `herc01` / `cul8tr` | FTP credentials |
| `TK5_PRINTER` | `hercules/tk5/prt/prt00e.txt` | printer file on the target |

Each environment must have its own TK5 running **and** its FTP server +
`tk5-ftp-watcher.sh` running (Section 6), since submission is via FTP.
