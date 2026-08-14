# COBOL Banking Application on MVS 3.8j TK4- (Docker)

## Prerequisites

```bash
sudo apt install -y docker.io c3270
```

---

## Directory Structure

```
Cobol Code Final/
├── cobol/                     # COBOL source & data
│   ├── COPYLIB/ACCTREC.cpy    # copybook
│   ├── VALDTRAN.cbl           # transaction validation
│   ├── UPDTBAL.cbl            # balance update
│   ├── RPRTGEN.cbl            # report generation
│   ├── TRANSIN.DAT           # sample transactions
│   └── ACCTMAST.DAT           # sample account master
├── jcl/                       # MVS JCL jobs
│   ├── BANKRUN.jcl            # execute full pipeline
│   ├── VALDTRAN.jcl           # compile + run VALDTRAN
│   ├── UPDTBAL.jcl            # compile + run UPDTBAL
│   └── RPRTGEN.jcl            # compile + run RPRTGEN
└── mainframe-ftp-lab/         # Docker TK4- environment
    ├── start-lab.sh            # start containers
    ├── stop-lab.sh             # stop containers
    ├── upload-ftp.sh           # upload COBOL files to FTP
    ├── ftphome/                # FTP-accessible files
    └── jcl/                    # JCL files
```

---

## Setup (c3270/ISPF)

### Step 1: Start

```bash
cd mainframe-ftp-lab
bash start-lab.sh               # Wait 30s for IPL
```

### Step 2: Connect

```bash
c3270 localhost:3270
# Login: HERC01 / CUL8TR
```

### Step 3: Allocate Datasets → ISPF 3.2

```
# ISPF Option 3.2 (Data Set Utility) — create 7 datasets:

# Partitioned (PO):
HERC01.COBOL     FB  80  800   TRK(5,1)   DIR=10
HERC01.COPYLIB   FB  80  800   TRK(1,1)   DIR=5
HERC01.LOAD      U    0  32760 TRK(5,1)   DIR=10
HERC01.JCL       FB  80  800   TRK(1,1)   DIR=10

# Sequential (PS):
HERC01.TRANSIN  FB  80  800   TRK(1,1)
HERC01.ACCTMAST  FB  80  800   TRK(1,1)
```

### Step 4: Populate COBOL Source → ISPF Edit

```
# ISPF Option 2 (Edit) → HERC01.COBOL
#  S VALDTRAN → paste from cobol/VALDTRAN.cbl → F3
#  S UPDTBAL  → paste from cobol/UPDTBAL.cbl  → F3
#  S RPRTGEN  → paste from cobol/RPRTGEN.cbl  → F3
```

### Step 5: Populate COPYLIB + Data + JCL → ISPF Edit

```
# ISPF Option 2 (Edit) → HERC01.COPYLIB
#  S ACCTREC → paste from cobol/COPYLIB/ACCTREC.cpy → F3

# ISPF Option 2 (Edit) → HERC01.TRANSIN
#  Paste from cobol/TRANSIN.DAT → F3

# ISPF Option 2 (Edit) → HERC01.ACCTMAST
#  Paste from cobol/ACCTMAST.DAT → F3

# ISPF Option 2 (Edit) → HERC01.JCL
#  S VALDTRAN → paste from jcl/VALDTRAN.jcl → F3
#  S UPDTBAL  → paste from jcl/UPDTBAL.jcl  → F3
#  S RPRTGEN  → paste from jcl/RPRTGEN.jcl  → F3
#  S BANKRUN  → paste from jcl/BANKRUN.jcl  → F3
```

### Step 6: Compile → ISPF Submit

```
# ISPF Option 3.4 (DSLIST) → HERC01.JCL
#  Type SUB next to VALDTRAN, Enter  (wait 30s)
#  Type SUB next to UPDTBAL, Enter   (wait 30s)
#  Type SUB next to RPRTGEN, Enter   (wait 30s)

# Check: ISPF 3.8 (OUTLIST) — look for IEWL link-edit
```

### Step 7: Run → ISPF Submit

```
# ISPF Option 3.4 (DSLIST) → HERC01.JCL
#  Type SUB next to BANKRUN, Enter
#  Wait 15-30s
```

### Step 8: Check Output → ISPF Outlist

```
# ISPF Option 3.8 (OUTLIST) — view BANKRUN output:
#   VALDTRAN → VALERRORS
#   UPDTBAL  → UPDATERPT
#   RPRTGEN  → FINALRPT

# Or browse datasets: ISPF 3.4 → HERC01.VALIDATE, HERC01.ACCTUPD
```

---

## FTP Commands (Reference)

```bash
# Upload single file
curl -T cobol/VALDTRAN.cbl ftp://dev:devpass@localhost:2121/VALDTRAN.cbl

# Upload all 6 files
bash mainframe-ftp-lab/upload-ftp.sh

# List FTP files
curl -l ftp://dev:devpass@localhost:2121/

# Download a file
curl ftp://dev:devpass@localhost:2121/VALDTRAN.cbl -o VALDTRAN.cbl

# Interactive FTP
ftp localhost 2121
# Name: dev / Password: devpass
```

---

## TSO Credentials

| User | Password |
|------|----------|
| HERC01 | CUL8TR |
| HERC02 | CUL8TR |

---

## Data File Formats

```
# TRANSIN.DAT (80 bytes)
# 1-10: Account | 11: Type(D/W) | 12-20: Amount(9(07)V99) | 21-28: Date | 29-58: Desc | 59-80: filler
# Amount: 000500000 = $5,000.00

# ACCTMAST.DAT (80 bytes)
# 1-10: Account | 11-40: Name | 41-51: Balance(9(09)V99) | 52: Status(A/C/F) | 53-60: Date | 61-80: filler
```

---

## Pipeline Flow

```
TRANSIN + ACCTMAST → VALDTRAN → VALIDATE + VALERRORS
VALIDATE + ACCTMAST → UPDTBAL  → ACCTUPD + UPDATERPT
ACCTUPD             → RPRTGEN  → FINALRPT
```

---

## Stop

```bash
cd mainframe-ftp-lab
bash stop-lab.sh
```

---

## Troubleshooting

```bash
docker ps                               # TK4 running? (ports 3270, 8038)
docker logs tk4 --tail 30              # Hercules logs

# FTP issues
docker logs ftp --tail 10              # FTP server logs
curl -l ftp://dev:devpass@localhost:2121/  # list FTP files
```
