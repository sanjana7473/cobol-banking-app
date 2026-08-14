//UPDTBAL  JOB (ACCT),'UPDATE',CLASS=A,MSGCLASS=X
//**************************************************************
//*  STEP 1: COMPILE UPDTBAL COBOL PROGRAM
//**************************************************************
//COBOL    EXEC COBUCG,PARM.COB='LOAD,NODECK'
//COBOL.SYSIN DD DSN=&SYSUID..COBOL(UPDTBAL),DISP=SHR
//COBOL.SYSLIB DD DSN=&SYSUID..COPYLIB,DISP=SHR
//COBOL.SYSPRINT DD SYSOUT=*
//COBOL.SYSLIN DD DSN=&&LOADSET,DISP=(MOD,PASS),
//             UNIT=SYSDA,SPACE=(CYL,(1,1))
//**************************************************************
//*  STEP 2: LINK-EDIT
//**************************************************************
//LKED     EXEC PGM=IEWL,PARM='LIST,XREF'
//SYSLIN   DD DSN=&&LOADSET,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=&SYSUID..LOAD(UPDTBAL),DISP=SHR
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSPRINT DD SYSOUT=*
//**************************************************************
//*  STEP 3: EXECUTE UPDTBAL
//**************************************************************
//RUN      EXEC PGM=UPDTBAL
//STEPLIB  DD DSN=&SYSUID..LOAD,DISP=SHR
//VALIDATE DD DSN=&SYSUID..VALIDATE,DISP=SHR
//ACCTMAST DD DSN=&SYSUID..ACCTMAST,DISP=SHR
//ACCTUPD  DD DSN=&SYSUID..ACCTUPD,DISP=(NEW,CATLG),
//             UNIT=SYSDA,SPACE=(TRK,(1,1)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=800)
//UPDATERPT DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
