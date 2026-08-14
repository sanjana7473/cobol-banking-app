# How to Run

## 1. Start Docker

```bash
cd "Cobol Code Final/mainframe-ftp-lab"
bash start-lab.sh
sleep 60
```

## 2. Run the Pipeline (one click)

```bash
bash run-all.sh
```

Or directly:

```bash
python3 run-all.py
```

This single command:
1. Creates `HERC01.LOAD` (load library)
2. Compiles all 3 COBOL programs (`VALDTRAN`, `UPDTBAL`, `RPRTGEN`)
3. Submits `BANKRUN` to validate transactions, update accounts, and generate reports
4. Displays the reports and saves to `reports/ALL_REPORTS.txt`

## 3. View Reports

### Option A: Command Line (fastest)

```bash
# Check return codes
curl -s http://localhost:8038/cgi-bin/tasks/syslog | sed 's/<[^>]*>//g' | grep IEFACTRT

# View the reports directly
cat reports/ALL_REPORTS.txt
```

### Option B: c3270 — Interactive Terminal (recommended)

`c3270` lets you type directly into the mainframe session like a normal terminal:

```bash
c3270 localhost:3270
```

- Login: type `HERC01` → Enter → `CUL8TR` → Enter
- You are now at the **RPF Primary Option Menu** (not ISPF):

```
RPF  ---  Primary Option Menu
Option ===> 
   0  Settings
   1  Browse
   2  Edit
   3  Utilities
   4  TSO Command
   5  SDSF
   6  VTAM
```

- Type `5` and press Enter → **SDSF** (Spool Display)
- Type `ST` (Status) and press Enter → see all jobs
- Move the cursor to **BANKRUN** and type `S` (Select) → view output
- Use **PF7** (up) / **PF8** (down) to scroll through the reports
- Use **PF3** (End) to go back

**c3270 keyboard shortcuts:**

| 3270 Key | Mapping |
|-----------|---------|
| Enter | `Enter` or `Ctrl+M` |
| PF1–PF12 | `Esc` + `1`–`9`, `0`, `-`, `=` |
| Clear | `Ctrl+L` |
| Quit | `Ctrl+C` |

### Option C: s3270 — Scripted / Command-Line

`s3270` is a **command-line tool** — you send commands to it, not keystrokes. Use this for scripting/automation:

```bash
s3270 localhost:3270
```

Once connected, the `s3270>` prompt accepts these commands:

```
s3270> String("HERC01")    # Type text into the session
s3270> Enter()              # Press Enter
s3270> String("CUL8TR")
s3270> Enter()
s3270> String("5")          # Select SDSF
s3270> Enter()
s3270> String("ST")         # Status (list jobs)
s3270> Enter()
s3270> Ascii()              # Dump screen text
s3270> Quit()               # Disconnect
```

Or pipe commands from a script:

```bash
echo 'Connect(localhost:3270)
Wait(15,Output)
Clear()
String("HERC01")
Enter()
Wait(5,Output)
Ascii()' | s3270
```

> **Note:** `s3270` interprets everything you type as an s3270 action. Typing `HERC01` directly gives `Unknown action` — you must use `String("HERC01")` to send text to the mainframe. For interactive manual use, `c3270` is the right tool.

## 4. Stop Docker

```bash
bash stop-lab.sh
```
