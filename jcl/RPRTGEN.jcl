//RPRTGEN  JOB (ACCT),'REPORT',CLASS=A,MSGCLASS=X
//**************************************************************
//*  STEP 1: COMPILE RPRTGEN COBOL PROGRAM
//**************************************************************
//COBOL    EXEC COBUCG,PARM.COB='LOAD,NODECK'
//COBOL.SYSIN DD DSN=&SYSUID..COBOL(RPRTGEN),DISP=SHR
//COBOL.SYSLIB DD DSN=&SYSUID..COPYLIB,DISP=SHR
//COBOL.SYSPRINT DD SYSOUT=*
//COBOL.SYSLIN DD DSN=&&LOADSET,DISP=(MOD,PASS),
//             UNIT=SYSDA,SPACE=(CYL,(1,1))
//**************************************************************
//*  STEP 2: LINK-EDIT
//**************************************************************
//LKED     EXEC PGM=IEWL,PARM='LIST,XREF'
//SYSLIN   DD DSN=&&LOADSET,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=&SYSUID..LOAD(RPRTGEN),DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSPRINT DD SYSOUT=*
//**************************************************************
//*  STEP 3: EXECUTE RPRTGEN
//**************************************************************
//RUN      EXEC PGM=RPRTGEN
//STEPLIB  DD DSN=&SYSUID..LOAD,DISP=SHR
//ACCTUPD  DD DSN=&SYSUID..ACCTUPD,DISP=SHR
//TRANSIN DD DSN=&SYSUID..TRANSIN,DISP=SHR
//FINALRPT DD SYSOUT=*
//SUMMARY  DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
