       IDENTIFICATION DIVISION.
       PROGRAM-ID. UPDTBAL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT VALIDATED-FILE     ASSIGN TO UT-S-VALIDATE.
           SELECT ACCOUNT-FILE       ASSIGN TO UT-S-ACCTMAST.
           SELECT UPDATED-ACCT-FILE  ASSIGN TO UT-S-ACCTUPD.
           SELECT UPDATE-REPORT      ASSIGN TO UT-S-UPDRPT.

       DATA DIVISION.
       FILE SECTION.

       FD  VALIDATED-FILE
           LABEL RECORDS ARE STANDARD.
       01  VALIDATED-REC             PIC X(80).

       FD  ACCOUNT-FILE
           LABEL RECORDS ARE STANDARD.
       01  ACCT-REC                  PIC X(80).

       FD  UPDATED-ACCT-FILE
           LABEL RECORDS ARE STANDARD.
       01  UPDATED-REC               PIC X(80).

       FD  UPDATE-REPORT
           LABEL RECORDS ARE STANDARD.
       01  REPORT-LINE               PIC X(80).
       01  REPORT-LINE-R REDEFINES REPORT-LINE.
           05  FILLER                PIC X(31).
           05  RPT-COUNT             PIC Z(5)9.
           05  FILLER                PIC X(43).

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

       01  WS-VALIDATED-RECORD       PIC X(80).
       01  WS-ACCOUNT-RECORD         PIC X(80).
       01  WS-UPDATED-ACCOUNT        PIC X(80).

       01  WS-STATUS-FLAGS.
           05  WS-VALIDATED-EOF      PIC X(01) VALUE 'N'.
               88  VALIDATED-EOF     VALUE 'Y'.

       01  WS-COUNTERS.
           05  WS-TRANS-PROCESSED    PIC 9(06) VALUE 0.
           05  WS-DEPOSITS           PIC 9(06) VALUE 0.
           05  WS-WITHDRAWALS        PIC 9(06) VALUE 0.

       01  WS-HEADER.
           05  FILLER                PIC X(30) VALUE
               'ACCOUNT UPDATE REPORT'.
           05  FILLER                PIC X(15) VALUE SPACES.
           05  WS-RUN-DATE           PIC 9(06).

       01  WS-TEMP-BALANCE           PIC 9(09)V99.

       01  WS-ACCT-ARRAY.
           05  WS-ACCT-ENTRY OCCURS 100 TIMES
               INDEXED BY WS-ACCT-IDX.
               10  WS-ACCT-NUMBER    PIC 9(10).
               10  WS-ACCT-NAME      PIC X(30).
               10  WS-ACCT-BALANCE   PIC 9(09)V99.
               10  WS-ACCT-STATUS    PIC X(01).
               10  WS-ACCT-UPDATE    PIC 9(08).
               10  WS-ACCT-REST      PIC X(20).

       01  WS-ACCT-COUNT             PIC 9(03) VALUE 0.

       01  WS-FLAGS.
           05  WS-LOAD-EOF            PIC X(01) VALUE 'N'.
           05  WS-UPDATE-DONE         PIC X(01) VALUE 'N'.

       PROCEDURE DIVISION.

       MAIN-LOGIC.
           PERFORM INITIALIZATION.
           PERFORM LOAD-ACCOUNTS.
           PERFORM PROCESS-VALIDATED THRU PROCESS-EXIT
               UNTIL VALIDATED-EOF.
           PERFORM WRITE-ALL-ACCOUNTS.
           PERFORM PRINT-SUMMARY.
           PERFORM CLEANUP.
           STOP RUN.

       INITIALIZATION.
           OPEN INPUT  VALIDATED-FILE
                INPUT  ACCOUNT-FILE
                OUTPUT UPDATED-ACCT-FILE
                OUTPUT UPDATE-REPORT.
           MOVE 260729 TO WS-RUN-DATE.
           WRITE REPORT-LINE FROM WS-HEADER.
           PERFORM READ-NEXT-VALIDATED.

       LOAD-ACCOUNTS.
           MOVE 0 TO WS-ACCT-COUNT.
           MOVE 'N' TO WS-LOAD-EOF.
           PERFORM LOAD-ACCOUNTS-LOOP
               UNTIL WS-ACCT-COUNT > 99
               OR WS-LOAD-EOF = 'Y'.

       LOAD-ACCOUNTS-LOOP.
           MOVE 'N' TO WS-LOAD-EOF.
           READ ACCOUNT-FILE INTO WS-ACCOUNT-RECORD
               AT END MOVE 'Y' TO WS-LOAD-EOF.
           IF WS-LOAD-EOF = 'N'
               ADD 1 TO WS-ACCT-COUNT
               MOVE WS-ACCOUNT-RECORD TO ACCOUNT-RECORD
               MOVE ACCT-NUMBER TO
                   WS-ACCT-NUMBER(WS-ACCT-COUNT)
               MOVE ACCT-HOLDER-NAME TO
                   WS-ACCT-NAME(WS-ACCT-COUNT)
               MOVE ACCT-BALANCE TO
                   WS-ACCT-BALANCE(WS-ACCT-COUNT)
               MOVE ACCT-STATUS TO
                   WS-ACCT-STATUS(WS-ACCT-COUNT)
               MOVE ACCT-LAST-UPDATE TO
                   WS-ACCT-UPDATE(WS-ACCT-COUNT).

       READ-NEXT-VALIDATED.
           MOVE 'N' TO WS-VALIDATED-EOF.
           READ VALIDATED-FILE INTO WS-VALIDATED-RECORD
               AT END MOVE 'Y' TO WS-VALIDATED-EOF.

       PROCESS-VALIDATED.
           MOVE WS-VALIDATED-RECORD TO VALIDATED-TRANSACTION-RECORD.
      *    Skip invalid transactions
           IF NOT VTR-VALID
               PERFORM READ-NEXT-VALIDATED
               GO TO PROCESS-EXIT.
           PERFORM UPDATE-ACCOUNT.
           ADD 1 TO WS-TRANS-PROCESSED.
           PERFORM READ-NEXT-VALIDATED.
       PROCESS-EXIT.
      *    End of process routine.

       UPDATE-ACCOUNT.
           MOVE 'N' TO WS-UPDATE-DONE.
           PERFORM UPDATE-ACCOUNT-LOOP
               VARYING WS-ACCT-IDX FROM 1 BY 1
               UNTIL WS-ACCT-IDX > WS-ACCT-COUNT
               OR WS-UPDATE-DONE = 'Y'.

       UPDATE-ACCOUNT-LOOP.
           IF WS-ACCT-NUMBER(WS-ACCT-IDX) =
              VTR-ACCOUNT-NUMBER
               MOVE WS-ACCT-BALANCE(WS-ACCT-IDX) TO
                   WS-TEMP-BALANCE
               IF VTR-TRANSACTION-TYPE = 'D'
                   ADD VTR-AMOUNT TO
                       WS-ACCT-BALANCE(WS-ACCT-IDX)
                   ADD 1 TO WS-DEPOSITS.
               IF VTR-TRANSACTION-TYPE = 'W'
                   SUBTRACT VTR-AMOUNT FROM
                       WS-ACCT-BALANCE(WS-ACCT-IDX)
                   ADD 1 TO WS-WITHDRAWALS.
               MOVE WS-RUN-DATE TO
                   WS-ACCT-UPDATE(WS-ACCT-IDX)
               MOVE 'Y' TO WS-UPDATE-DONE.

       WRITE-ALL-ACCOUNTS.
           PERFORM WRITE-ACCOUNT-LOOP
               VARYING WS-ACCT-IDX FROM 1 BY 1
               UNTIL WS-ACCT-IDX > WS-ACCT-COUNT.

       WRITE-ACCOUNT-LOOP.
           MOVE WS-ACCT-NUMBER(WS-ACCT-IDX) TO ACCT-NUMBER.
           MOVE WS-ACCT-NAME(WS-ACCT-IDX) TO
               ACCT-HOLDER-NAME.
           MOVE WS-ACCT-BALANCE(WS-ACCT-IDX) TO
               ACCT-BALANCE.
           MOVE WS-ACCT-STATUS(WS-ACCT-IDX) TO
               ACCT-STATUS.
           MOVE WS-ACCT-UPDATE(WS-ACCT-IDX) TO
               ACCT-LAST-UPDATE.
           MOVE ACCOUNT-RECORD TO WS-UPDATED-ACCOUNT.
           WRITE UPDATED-REC FROM WS-UPDATED-ACCOUNT.

       PRINT-SUMMARY.
           MOVE SPACES TO REPORT-LINE.
           WRITE REPORT-LINE.
           MOVE 'UPDATE SUMMARY' TO REPORT-LINE.
           WRITE REPORT-LINE.
           MOVE SPACES TO REPORT-LINE.
           WRITE REPORT-LINE.
           MOVE 'TOTAL TRANSACTIONS PROCESSED: ' TO REPORT-LINE.
           MOVE WS-TRANS-PROCESSED TO RPT-COUNT.
           WRITE REPORT-LINE.
           MOVE 'DEPOSITS PROCESSED:          ' TO REPORT-LINE.
           MOVE WS-DEPOSITS TO RPT-COUNT.
           WRITE REPORT-LINE.
           MOVE 'WITHDRAWALS PROCESSED:       ' TO REPORT-LINE.
           MOVE WS-WITHDRAWALS TO RPT-COUNT.
           WRITE REPORT-LINE.

       CLEANUP.
           CLOSE VALIDATED-FILE
                 ACCOUNT-FILE
                 UPDATED-ACCT-FILE
                 UPDATE-REPORT.
