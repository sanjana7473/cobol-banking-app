c3270 localhost:3270

ftp localhost 2121

Then type these commands inside the FTP prompt:

Name: herc01
Password: cul8tr
ftp> put /tmp/00_delete.jcl 00_delete.jcl
ftp> put /tmp/01_alloc.jcl 01_alloc.jcl
ftp> put /tmp/02_valdcomp.jcl 02_valdcomp.jcl
ftp> put /tmp/03_updtcomp.jcl 03_updtcomp.jcl
ftp> put /tmp/04_rprtcomp.jcl 04_rprtcomp.jcl
ftp> put /tmp/05_bankrun.jcl 05_bankrun.jcl
ftp> quit

ISPF > R > 1 - VALIDITY, LOAD, ACCTUPD



+-----------------+------------------------------------+
| Method          | When to use                        |
+-----------------+------------------------------------+
| curl -T         | Scripts, one-liners, automation    |
| ftp interactive | Manual uploads, exploring, ls to   |
|                 | see files                          |
+-----------------+------------------------------------+

Both do the same thing — the watcher picks up the file and submits it to TK5. Your choice!

• Thinking
  The user asked "view report command" — they want the terminal command to
  view the reports themselves. Let me give them the simple command they can run.

Run this in your terminal:

```bash
head -n 28 "/home/ubuntu/Cobol Code Final/reports/ALL_REPORTS_TK5.txt"


