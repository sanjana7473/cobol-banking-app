# TK5 — Terminal-Only Commands

## Start TK5

```
# Launch Hercules with TK5 config, wait for IPL, verify it's ready
cd "/home/ubuntu/Meshach Cobol Code_Cobol Code/hercules/tk5"
export PATH="$(pwd)/hercules/linux/64/bin:$PATH"
export LD_LIBRARY_PATH="$(pwd)/hercules/linux/64/lib:$(pwd)/hercules/linux/64/lib/hercules:$LD_LIBRARY_PATH"
export HERCULES_RC=scripts/ipl.rc
nohup hercules/linux/64/bin/hercules -d -f conf/tk5.cnf > log/3033.log 2>&1 &
sleep 60
curl -s http://localhost:8038/cgi-bin/tasks/syslog | sed 's/<[^>]*>//g' | grep "HASP000 OK"
```

## Start FTP

```
# Start FTP Docker container + watcher that sends uploaded files to TK5 port 3505
sg docker -c "docker run -d --name tk5-ftp -p 2121:21 -p 30000-30009:30000-30009 -v '/home/ubuntu/Meshach Cobol Code_Cobol Code/hercules/tk5/rdr:/home/ftpuser/jcl' -e FTP_USER_NAME=herc01 -e FTP_USER_PASS=cul8tr -e FTP_USER_HOME=/home/ftpuser/jcl stilliard/pure-ftpd"
cd "/home/ubuntu/Cobol Code Final"
nohup bash tk5-ftp-watcher.sh > /tmp/tk5-ftp-watcher.log 2>&1 &
```

## Upload JCL via FTP

```
# ALLOC — create HERC01.LOAD
echo "//ALLOC    JOB (ACCT),'ALLOC',CLASS=A,USER=HERC01,PASSWORD=CUL8TR
//STEP     EXEC PGM=IEFBR14
//LOAD     DD DSN=HERC01.LOAD,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(1,1,10)),
//             DCB=(RECFM=U,LRECL=0,BLKSIZE=32760)
//SYSOUT   DD SYSOUT=*
//" > /tmp/alloc.jcl
curl -T /tmp/alloc.jcl ftp://localhost:2121/ --user herc01:cul8tr
sleep 5
```

```
# RPRTCOMP — compile RPRTGEN.cbl
echo "//RPRTCOMP JOB (ACCT),'COMP-RPRT',CLASS=A,USER=HERC01,PASSWORD=CUL8TR
//COB      EXEC PGM=IKFCBL00,PARM='LOAD,NODECK,SIZE=2048K,BUF=1024K'
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSUT2   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSUT3   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSUT4   DD UNIT=SYSDA,SPACE=(460,(700,100))
//SYSLIN   DD DSN=&&LOADSET,DISP=(MOD,PASS),
//             UNIT=SYSDA,SPACE=(80,(500,100))
//SYSIN    DD DATA
$(cat "/home/ubuntu/Cobol Code Final/cobol/RPRTGEN.cbl")
/*
//SYSPUNCH DD DUMMY
//LKED     EXEC PGM=IEWL,PARM='LIST,XREF'
//SYSLIB   DD DSN=SYS1.COBLIB,DISP=SHR
//SYSLIN   DD DSN=&&LOADSET,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=HERC01.LOAD(RPRTGEN),DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSPRINT DD SYSOUT=*
//" > /tmp/rprtcomp.jcl
curl -T /tmp/rprtcomp.jcl ftp://localhost:2121/ --user herc01:cul8tr
sleep 5
```

## Check Job Status

```
# See which jobs completed
curl -s http://localhost:8038/cgi-bin/tasks/syslog | sed 's/<[^>]*>//g' | grep IEF404I
# See return codes
curl -s http://localhost:8038/cgi-bin/tasks/syslog | sed 's/<[^>]*>//g' | grep IEFACTRT
```

## View Reports

```
# Show report headers
cat "/home/ubuntu/Meshach Cobol Code_Cobol Code/hercules/tk5/prt/prt00e.txt" | grep -a "VALIDATION REPORT\|UPDATE REPORT\|BALANCE REPORT"
```

```
# Extract full BANKRUN section from printer
PRT="/home/ubuntu/Meshach Cobol Code_Cobol Code/hercules/tk5/prt/prt00e.txt"
START=$(grep -an "START  JOB.*BANKRUN" "$PRT" | tail -1 | cut -d: -f1)
END=$(grep -an "END   JOB.*BANKRUN" "$PRT" | tail -1 | cut -d: -f1)
sed -n "${START},${END}p" "$PRT"
```

## Verify Datasets in c3270

```
# Connect and login
c3270 localhost:3270
# Login: HERC01 / CUL8TR
```

```
# Quick path to RPF Browse:
# ISPF → R → PF3 → 1 → Enter
```

```
# Browse HERC01.LOAD (PDS — shows member list)
# On RPFED entry panel:
# Data Set Name ===> HERC01.LOAD
```

```
# Browse HERC01.VALIDATE (80-byte validated transactions)
# PF3 to go back, then:
# Data Set Name ===> HERC01.VALIDATE
```

```
# Browse HERC01.ACCTUPD (80-byte updated balances)
# PF3 to go back, then:
# Data Set Name ===> HERC01.ACCTUPD
```

## Stop TK5

```
# Kill Hercules, verify ports are clear
pkill -9 -f hercules
ss -tlnp | grep -E "3270|3505|8038"
```

## Stop FTP

```
# Stop FTP container and watcher
sg docker -c "docker stop tk5-ftp && docker rm tk5-ftp"
pkill -f tk5-ftp-watcher
```

## c3270 — Re-Run BANKRUN

```
# Connect
c3270 localhost:3270
```

```
# Login
# HERC01 → Enter → CUL8TR → Enter
```

```
# Go to TSO Command
# ISPF menu → 6 → Enter
```

```
# Submit BANKRUN from saved JCL
# SUB 'HERC01.JCLLIB(BANKRUN)'
```

```
# Immediately view output before it gets purged
# =R → PF3 → 3 → 6 → L → cursor BANKRUN → Enter
```
