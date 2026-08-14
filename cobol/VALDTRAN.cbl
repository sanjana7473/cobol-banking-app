       IDENTIFICATION DIVISION.
       PROGRAM-ID. VALDTRAN.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TRANSACTION-FILE   ASSIGN TO UT-S-TRANSIN.
           SELECT VALIDATED-FILE     ASSIGN TO UT-S-VALIDATE.
           SELECT ERROR-REPORT       ASSIGN TO UT-S-VALERR.
           SELECT ACCOUNT-FILE       ASSIGN TO UT-S-ACCTMAST.

       DATA DIVISION.
       FILE SECTION.

       FD  TRANSACTION-FILE
           LABEL RECORDS ARE STANDARD.
       01  TRANS-REC                 PIC X(80).

       FD  VALIDATED-FILE
           LABEL RECORDS ARE STANDARD.
       01  VALIDATED-REC             PIC X(80).

       FD  ERROR-REPORT
           LABEL RECORDS ARE STANDARD.
       01  ERROR-LINE                PIC X(80).
       01  ERROR-LINE-R REDEFINES ERROR-LINE.
           05  FILLER                PIC X(27).
           05  ERR-COUNT             PIC Z(5)9.
           05  FILLER                PIC X(47).

       FD  ACCOUNT-FILE
           LABEL RECORDS ARE STANDARD.
       01  ACCT-REC                  PIC X(80).

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

       01  WS-TRANSACTION-RECORD     PIC X(80).
       01  WS-VALIDATED-RECORD       PIC X(80).
       01  WS-ACCOUNT-RECORD         PIC X(80).

       01  WS-STATUS-FLAGS.
           05  WS-TRANS-FILE-EOF     PIC X(01) VALUE 'N'.
               88  TRANS-EOF         VALUE 'Y'.
           05  WS-ACCT-FILE-EOF      PIC X(01) VALUE 'N'.
               88  ACCT-EOF          VALUE 'Y'.
           05  WS-ACCT-FOUND         PIC X(01) VALUE 'N'.
               88  ACCT-FOUND        VALUE 'Y'.

       01  WS-COUNTERS.
           05  WS-TRANS-READ         PIC 9(06) VALUE 0.
           05  WS-TRANS-VALID        PIC 9(06) VALUE 0.
           05  WS-TRANS-INVALID      PIC 9(06) VALUE 0.

       01  WS-HEADER.
           05  FILLER                PIC X(30) VALUE
               'TRANSACTION VALIDATION REPORT'.
           05  FILLER                PIC X(15) VALUE SPACES.
           05  WS-RUN-DATE           PIC 9(06).

       01  WS-ERROR-HEADER.
           05  FILLER                PIC X(08) VALUE 'ACCOUNT '.
           05  FILLER                PIC X(12) VALUE 'TRANS TYPE '.
           05  FILLER                PIC X(12) VALUE 'AMOUNT    '.
           05  FILLER                PIC X(10) VALUE 'ERROR     '.
           05  FILLER                PIC X(38) VALUE SPACES.

       PROCEDURE DIVISION.

       MAIN-LOGIC.
           PERFORM INITIALIZATION.
           PERFORM PROCESS-TRANSACTIONS
               UNTIL TRANS-EOF.
           PERFORM PRINT-SUMMARY.
           PERFORM CLEANUP.
           STOP RUN.

       INITIALIZATION.
           OPEN INPUT  TRANSACTION-FILE
                INPUT  ACCOUNT-FILE
                OUTPUT VALIDATED-FILE
                OUTPUT ERROR-REPORT.
           MOVE 260729 TO WS-RUN-DATE.
           WRITE ERROR-LINE FROM WS-HEADER.
           PERFORM READ-NEXT-TRANSACTION.

       READ-NEXT-TRANSACTION.
           MOVE 'N' TO WS-TRANS-FILE-EOF.
           READ TRANSACTION-FILE INTO WS-TRANSACTION-RECORD
               AT END MOVE 'Y' TO WS-TRANS-FILE-EOF.
           IF NOT TRANS-EOF
               ADD 1 TO WS-TRANS-READ.

       PROCESS-TRANSACTIONS.
           MOVE WS-TRANSACTION-RECORD TO TRANSACTION-RECORD.
           PERFORM VALIDATE-TRANSACTION.
           PERFORM READ-NEXT-TRANSACTION.

       VALIDATE-TRANSACTION.
           MOVE 00 TO VTR-ERROR-CODE.
           MOVE 'V' TO VTR-STATUS.

           MOVE TR-ACCOUNT-NUMBER   TO VTR-ACCOUNT-NUMBER.
           MOVE TR-TRANSACTION-TYPE TO VTR-TRANSACTION-TYPE.
           MOVE TR-AMOUNT           TO VTR-AMOUNT.
           MOVE TR-DATE             TO VTR-DATE.
           MOVE TR-DESCRIPTION      TO VTR-DESCRIPTION.

      *    Validate transaction type
           IF NOT TR-DEPOSIT AND NOT TR-WITHDRAWAL
               MOVE 'I' TO VTR-STATUS
               MOVE 02 TO VTR-ERROR-CODE
               PERFORM WRITE-INVALID-TRANS
               GO TO VALIDATE-EXIT.

      *    Validate amount
           IF TR-AMOUNT = 0
               MOVE 'I' TO VTR-STATUS
               MOVE 03 TO VTR-ERROR-CODE
               PERFORM WRITE-INVALID-TRANS
               GO TO VALIDATE-EXIT.

      *    Look up account
           PERFORM FIND-ACCOUNT.
           IF NOT ACCT-FOUND
               MOVE 'I' TO VTR-STATUS
               MOVE 01 TO VTR-ERROR-CODE
               PERFORM WRITE-INVALID-TRANS
               GO TO VALIDATE-EXIT.

      *    Check account status
           IF ACCT-CLOSED
               MOVE 'I' TO VTR-STATUS
               MOVE 04 TO VTR-ERROR-CODE
               PERFORM WRITE-INVALID-TRANS
               GO TO VALIDATE-EXIT.

           IF ACCT-FROZEN
               MOVE 'I' TO VTR-STATUS
               MOVE 05 TO VTR-ERROR-CODE
               PERFORM WRITE-INVALID-TRANS
               GO TO VALIDATE-EXIT.

      *    For withdrawals, check sufficient funds
           IF TR-WITHDRAWAL AND TR-AMOUNT > ACCT-BALANCE
               MOVE 'I' TO VTR-STATUS
               MOVE 06 TO VTR-ERROR-CODE
               PERFORM WRITE-INVALID-TRANS
               GO TO VALIDATE-EXIT.

      *    Transaction is valid
           MOVE VALIDATED-TRANSACTION-RECORD TO WS-VALIDATED-RECORD.
           WRITE VALIDATED-REC FROM WS-VALIDATED-RECORD.
           ADD 1 TO WS-TRANS-VALID.
       VALIDATE-EXIT.
      *    End of validation routine.

       FIND-ACCOUNT.
           MOVE 'N' TO WS-ACCT-FOUND.
           CLOSE ACCOUNT-FILE.
           OPEN INPUT ACCOUNT-FILE.
           MOVE 'N' TO WS-ACCT-FILE-EOF.
           PERFORM FIND-ACCOUNT-LOOP UNTIL ACCT-EOF.

       FIND-ACCOUNT-LOOP.
           MOVE 'N' TO WS-ACCT-FILE-EOF.
           READ ACCOUNT-FILE INTO WS-ACCOUNT-RECORD
               AT END MOVE 'Y' TO WS-ACCT-FILE-EOF.
           IF NOT ACCT-EOF
               MOVE WS-ACCOUNT-RECORD TO ACCOUNT-RECORD
               IF ACCT-NUMBER = TR-ACCOUNT-NUMBER
                   MOVE 'Y' TO WS-ACCT-FOUND
                   MOVE 'Y' TO WS-ACCT-FILE-EOF.

       WRITE-INVALID-TRANS.
           MOVE VALIDATED-TRANSACTION-RECORD TO WS-VALIDATED-RECORD.
           WRITE VALIDATED-REC FROM WS-VALIDATED-RECORD.
           ADD 1 TO WS-TRANS-INVALID.

       PRINT-SUMMARY.
           MOVE SPACES TO ERROR-LINE.
           WRITE ERROR-LINE.
           MOVE 'VALIDATION SUMMARY' TO ERROR-LINE.
           WRITE ERROR-LINE.
           MOVE SPACES TO ERROR-LINE.
           WRITE ERROR-LINE.
           MOVE 'TOTAL TRANSACTIONS READ:  ' TO ERROR-LINE.
           MOVE WS-TRANS-READ TO ERR-COUNT.
           WRITE ERROR-LINE.
           MOVE 'VALID TRANSACTIONS:       ' TO ERROR-LINE.
           MOVE WS-TRANS-VALID TO ERR-COUNT.
           WRITE ERROR-LINE.
           MOVE 'INVALID TRANSACTIONS:     ' TO ERROR-LINE.
           MOVE WS-TRANS-INVALID TO ERR-COUNT.
           WRITE ERROR-LINE.

       CLEANUP.
           CLOSE TRANSACTION-FILE
                 ACCOUNT-FILE
                 VALIDATED-FILE
                 ERROR-REPORT.
