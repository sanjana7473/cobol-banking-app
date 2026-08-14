       IDENTIFICATION DIVISION.
       PROGRAM-ID. RPRTGEN.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT UPDATED-ACCT-FILE  ASSIGN TO UT-S-ACCTUPD.
           SELECT REPORT-FILE        ASSIGN TO UT-S-FINALRPT.

       DATA DIVISION.
       FILE SECTION.

       FD  UPDATED-ACCT-FILE
           LABEL RECORDS ARE STANDARD.
       01  UPDATED-REC               PIC X(80).

       FD  REPORT-FILE
           LABEL RECORDS ARE STANDARD.
       01  REPORT-LINE               PIC X(80).

       WORKING-STORAGE SECTION.

      *    Inlined from COPY ACCTREC
       01  TRANSACTION-RECORD.
           05  TR-ACCOUNT-NUMBER      PIC 9(10).
           05  TR-TRANSACTION-TYPE    PIC X(01).
               88  TR-DEPOSIT         VALUE 'D'.
               88  TR-WITHDRAWAL      VALUE 'W'.
           05  TR-AMOUNT              PIC 9(07)V99.
           05  TR-DATE                PIC 9(08).
           05  TR-DESCRIPTION         PIC X(30).
           05  FILLER                 PIC X(22).

       01  ACCOUNT-RECORD.
           05  ACCT-NUMBER            PIC 9(10).
           05  ACCT-HOLDER-NAME       PIC X(30).
           05  ACCT-BALANCE           PIC 9(09)V99.
           05  ACCT-STATUS            PIC X(01).
               88  ACCT-ACTIVE        VALUE 'A'.
               88  ACCT-CLOSED        VALUE 'C'.
               88  ACCT-FROZEN        VALUE 'F'.
           05  ACCT-LAST-UPDATE       PIC 9(08).
           05  FILLER                 PIC X(20).

       01  VALIDATED-TRANSACTION-RECORD.
           05  VTR-ACCOUNT-NUMBER     PIC 9(10).
           05  VTR-TRANSACTION-TYPE   PIC X(01).
           05  VTR-AMOUNT             PIC 9(07)V99.
           05  VTR-DATE               PIC 9(08).
           05  VTR-DESCRIPTION        PIC X(30).
           05  VTR-STATUS             PIC X(01).
               88  VTR-VALID          VALUE 'V'.
               88  VTR-INVALID        VALUE 'I'.
           05  VTR-ERROR-CODE         PIC 9(02).
               88  ERR-NONE           VALUE 00.
               88  ERR-INVALID-ACCT   VALUE 01.
               88  ERR-INVALID-TYPE   VALUE 02.
               88  ERR-INVALID-AMT    VALUE 03.
               88  ERR-ACCT-CLOSED    VALUE 04.
               88  ERR-ACCT-FROZEN    VALUE 05.
               88  ERR-INSUFF-FUNDS   VALUE 06.
           05  FILLER                 PIC X(19).

       01  WS-UPDATED-ACCT           PIC X(80).
       01  WS-TRANSACTION            PIC X(80).

       01  WS-STATUS-FLAGS.
           05  WS-ACCT-EOF           PIC X(01) VALUE 'N'.
               88  ACCT-EOF          VALUE 'Y'.

       01  WS-COUNTERS.
           05  WS-ACCTS-REPORTED     PIC 9(06) VALUE 0.
           05  WS-TOTAL-BALANCE      PIC 9(12)V99 VALUE 0.

       01  WS-HEADER-1.
           05  FILLER                PIC X(40) VALUE
               'BANK ACCOUNT BALANCE REPORT'.
           05  FILLER                PIC X(10) VALUE SPACES.
           05  WS-RUN-DATE           PIC 9(06).
           05  FILLER                PIC X(22) VALUE SPACES.

       01  WS-HEADER-2.
           05  FILLER                PIC X(12) VALUE 'ACCOUNT    '.
           05  FILLER                PIC X(32) VALUE
               'HOLDER NAME                    '.
           05  FILLER                PIC X(15) VALUE 'BALANCE        '.
           05  FILLER                PIC X(11) VALUE 'STATUS     '.
           05  FILLER                PIC X(10) VALUE SPACES.

       01  WS-DETAIL-LINE.
           05  DL-ACCOUNT            PIC 9(10).
           05  FILLER                PIC X(02) VALUE SPACES.
           05  DL-NAME               PIC X(30).
           05  FILLER                PIC X(02) VALUE SPACES.
           05  DL-BALANCE            PIC $$$$$$$9.99.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  DL-STATUS             PIC X(10).
           05  FILLER                PIC X(08) VALUE SPACES.

       01  WS-SUMMARY-LINE.
           05  FILLER                PIC X(30) VALUE
               'TOTAL ACCOUNTS REPORTED:   '.
           05  SL-ACCT-COUNT         PIC Z(06)9.
           05  FILLER                PIC X(24) VALUE SPACES.

       01  WS-BALANCE-LINE.
           05  FILLER                PIC X(30) VALUE
               'COMBINED TOTAL BALANCE:    '.
           05  SL-TOTAL-BALANCE      PIC $$$$$$$$$$$9.99.
           05  FILLER                PIC X(15) VALUE SPACES.

       PROCEDURE DIVISION.

       MAIN-LOGIC.
           PERFORM INITIALIZATION.
           PERFORM GENERATE-REPORT
               UNTIL ACCT-EOF.
           PERFORM PRINT-SUMMARY.
           PERFORM CLEANUP.
           STOP RUN.

       INITIALIZATION.
           OPEN INPUT  UPDATED-ACCT-FILE
                OUTPUT REPORT-FILE.
           MOVE 260729 TO WS-RUN-DATE.
           WRITE REPORT-LINE FROM WS-HEADER-1.
           MOVE SPACES TO REPORT-LINE.
           WRITE REPORT-LINE.
           WRITE REPORT-LINE FROM WS-HEADER-2.
           MOVE ALL '-' TO REPORT-LINE.
           WRITE REPORT-LINE.
           PERFORM READ-NEXT-ACCOUNT.

       READ-NEXT-ACCOUNT.
           MOVE 'N' TO WS-ACCT-EOF.
           READ UPDATED-ACCT-FILE INTO WS-UPDATED-ACCT
               AT END MOVE 'Y' TO WS-ACCT-EOF.

       GENERATE-REPORT.
           MOVE WS-UPDATED-ACCT TO ACCOUNT-RECORD.
           MOVE ACCT-NUMBER      TO DL-ACCOUNT.
           MOVE ACCT-HOLDER-NAME TO DL-NAME.
           MOVE ACCT-BALANCE     TO DL-BALANCE.

           IF ACCT-ACTIVE
               MOVE 'ACTIVE'    TO DL-STATUS
           ELSE
               IF ACCT-CLOSED
                   MOVE 'CLOSED'    TO DL-STATUS
               ELSE
                   IF ACCT-FROZEN
                       MOVE 'FROZEN'    TO DL-STATUS
                   ELSE
                       MOVE 'UNKNOWN'   TO DL-STATUS.

           WRITE REPORT-LINE FROM WS-DETAIL-LINE.
           ADD ACCT-BALANCE TO WS-TOTAL-BALANCE.
           ADD 1 TO WS-ACCTS-REPORTED.
           PERFORM READ-NEXT-ACCOUNT.

       PRINT-SUMMARY.
           MOVE SPACES TO REPORT-LINE.
           WRITE REPORT-LINE.
           MOVE ALL '=' TO REPORT-LINE.
           WRITE REPORT-LINE.
           MOVE WS-ACCTS-REPORTED TO SL-ACCT-COUNT.
           WRITE REPORT-LINE FROM WS-SUMMARY-LINE.
           MOVE WS-TOTAL-BALANCE TO SL-TOTAL-BALANCE.
           WRITE REPORT-LINE FROM WS-BALANCE-LINE.

       CLEANUP.
           CLOSE UPDATED-ACCT-FILE
                 REPORT-FILE.
